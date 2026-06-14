<?php

namespace App\Console\Commands;

use App\Models\Fee;
use App\Models\Notification;
use App\Models\Restriction;
use Carbon\Carbon;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

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

        $start  = Carbon::parse($semesterStart)->startOfDay();
        $today  = Carbon::today();
        $dayNum = $start->diffInDays($today) + 1;
        $week   = (int) ceil($dayNum / 7);

        if ($week < 5) {
            $this->info("Currently Week {$week} — restriction not yet applicable.");
            return self::SUCCESS;
        }

        $this->info("Week {$week} detected. Enforcing Week 5 financial bar...");

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
                // GAP 6: wrap each restriction creation in try-catch
                try {
                    Restriction::create([
                        'user_id'          => $userId,
                        'restriction_type' => 'financial_bar',
                        'status'           => 'active',
                        'applied_date'     => $today->toDateString(),
                    ]);

                    // GAP 2: send restriction notification to student
                    $outstandingFee = Fee::where('user_id', $userId)
                        ->whereIn('status', ['unpaid', 'partial'])
                        ->orderBy('due_date')
                        ->first();

                    $semester = $outstandingFee?->semester ?? 'current semester';
                    $balance  = $outstandingFee
                        ? number_format($outstandingFee->amount - $outstandingFee->amount_paid, 2)
                        : '0.00';

                    Notification::create([
                        'user_id' => $userId,
                        'title'   => 'Academic Access Restricted',
                        'message' => "Your academic access has been restricted due to unpaid tuition fees for {$semester}. "
                            . "Outstanding balance: RM{$balance}. Please make payment immediately to restore access.",
                        'type' => 'restriction',
                    ]);

                    $applied++;
                } catch (\Exception $e) {
                    // GAP 6: log but continue to next student
                    Log::error("EnforceWeek5Restriction: failed for user {$userId}: " . $e->getMessage());
                }
            }
        }

        $this->info("Done. {$applied} new restriction(s) applied.");
        return self::SUCCESS;
    }
}
