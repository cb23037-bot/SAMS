<?php

namespace App\Console\Commands;

use App\Models\Fee;
use App\Models\Restriction;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class EnforceWeek5Restriction extends Command
{
    protected $signature   = 'fees:enforce-week5';
    protected $description = 'Apply financial_bar restrictions to students with unpaid/partial fees past Week 5';

    public function handle(): int
    {
        $autoEnforce = DB::table('settings')->where('key', 'week5_auto_enforce')->value('value');
        if ($autoEnforce !== 'true') {
            $this->info('Week 5 auto-enforce is disabled. Skipping.');
            return self::SUCCESS;
        }

        $semesterStart = DB::table('settings')->where('key', 'semester_start_date')->value('value');
        if (!$semesterStart) {
            $this->error('semester_start_date not set in settings table.');
            return self::FAILURE;
        }

        $start   = Carbon::parse($semesterStart)->startOfDay();
        $today   = Carbon::today();
        $dayNum  = $start->diffInDays($today) + 1; // day 1 = semester start
        $week    = (int) ceil($dayNum / 7);

        if ($week < 5) {
            $this->info("Currently Week {$week} — restriction not yet applicable.");
            return self::SUCCESS;
        }

        $this->info("Week {$week} detected. Enforcing Week 5 financial bar...");

        // Students with at least one unpaid or partial fee
        $restrictedUserIds = Fee::whereIn('status', ['unpaid', 'partial'])
            ->pluck('user_id')
            ->unique();

        $applied = 0;
        foreach ($restrictedUserIds as $userId) {
            $already = Restriction::where('user_id', $userId)
                ->where('restriction_type', 'financial_bar')
                ->where('status', 'active')
                ->exists();

            if (!$already) {
                Restriction::create([
                    'user_id'          => $userId,
                    'restriction_type' => 'financial_bar',
                    'status'           => 'active',
                    'applied_date'     => $today->toDateString(),
                ]);
                $applied++;
            }
        }

        $this->info("Done. {$applied} new restriction(s) applied.");
        return self::SUCCESS;
    }
}
