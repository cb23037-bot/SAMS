<?php

namespace Database\Seeders;

use App\Models\Fee;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Database\Seeder;

class FeeSeeder extends Seeder
{
    public function run(): void
    {
        $records = [
            [
                'email'       => 'cb23037@adab.umpsa.edu.my',
                'semester'    => '2025/2026-1',
                'description' => 'Semester Tuition and Services Fee',
                'amount'      => 8450.00,
                'paid'        => 6940.00,
                'due_date'    => '2025-10-15',
                'method'      => 'online_banking',
                'reference'   => 'TEST-CB23037-001',
                'paid_at'     => '2025-09-20 10:15:00',
            ],
            [
                'email'       => 'cb23022@adab.umpsa.edu.my',
                'semester'    => '2025/2026-1',
                'description' => 'Semester Tuition Fee',
                'amount'      => 3200.00,
                'paid'        => 0.00,
                'due_date'    => '2025-10-15',
            ],
            [
                'email'       => 'cb23065@adab.umpsa.edu.my',
                'semester'    => '2025/2026-1',
                'description' => 'Semester Tuition and Accommodation Fee',
                'amount'      => 8450.00,
                'paid'        => 8450.00,
                'due_date'    => '2025-10-15',
                'method'      => 'card',
                'reference'   => 'TEST-CB23065-001',
                'paid_at'     => '2025-09-12 14:30:00',
            ],
            [
                'email'       => 'cb23111@adab.umpsa.edu.my',
                'semester'    => '2025/2026-1',
                'description' => 'Semester Tuition Fee',
                'amount'      => 4100.00,
                'paid'        => 1500.00,
                'due_date'    => '2025-10-30',
                'method'      => 'ewallet',
                'reference'   => 'TEST-CB23111-001',
                'paid_at'     => '2025-09-28 09:45:00',
            ],
            [
                'email'       => 'cb23111@adab.umpsa.edu.my',
                'semester'    => '2025/2026-2',
                'description' => 'Lab and Resource Fee',
                'amount'      => 650.00,
                'paid'        => 0.00,
                'due_date'    => '2026-03-15',
            ],
        ];

        foreach ($records as $record) {
            $student = User::where('email', $record['email'])->first();
            if (!$student) {
                continue;
            }

            $fee = Fee::updateOrCreate(
                [
                    'user_id'     => $student->id,
                    'semester'    => $record['semester'],
                    'description' => $record['description'],
                ],
                [
                    'amount'      => $record['amount'],
                    'amount_paid' => $record['paid'],
                    'due_date'    => $record['due_date'],
                    'status'      => $this->statusFor($record['amount'], $record['paid']),
                ],
            );

            if ($record['paid'] <= 0) {
                $fee->payments()->delete();
                continue;
            }

            Payment::updateOrCreate(
                ['reference_no' => $record['reference']],
                [
                    'fee_id'         => $fee->id,
                    'user_id'        => $student->id,
                    'amount'         => $record['paid'],
                    'payment_method' => $record['method'],
                    'paid_at'        => $record['paid_at'],
                ],
            );
        }
    }

    private function statusFor(float $amount, float $paid): string
    {
        return match (true) {
            $paid <= 0       => 'unpaid',
            $paid >= $amount => 'paid',
            default          => 'partial',
        };
    }
}
