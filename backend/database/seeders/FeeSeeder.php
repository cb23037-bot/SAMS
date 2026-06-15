<?php

namespace Database\Seeders;

use App\Models\Fee;
use App\Models\Payment;
use App\Models\Restriction;
use App\Models\Sponsor;
use App\Models\Student;
use App\Models\User;
use Carbon\Carbon;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class FeeSeeder extends Seeder
{
    public function run(): void
    {
        // ── Settings ────────────────────────────────────────────────────────
        DB::table('settings')->upsert([
            ['key' => 'semester_start_date', 'value' => '2026-01-06', 'updated_at' => now()],
            ['key' => 'week5_auto_enforce',  'value' => 'true',       'updated_at' => now()],
        ], ['key'], ['value', 'updated_at']);

        // ── Treasury user ────────────────────────────────────────────────────
        User::query()->updateOrCreate(
            ['email' => 'treasury@adab.umpsa.edu.my'],
            [
                'name'             => 'Treasury Office',
                'role'             => 'treasury',
                'student_id'       => null,
                'current_semester' => null,
                'password'         => Hash::make('123456'),
            ]
        );

        // ── Students ─────────────────────────────────────────────────────────
        $studentData = [
            [
                'name'             => 'Muhammad Ammar bin Azizan',
                'email'            => 'cb23037@adab.umpsa.edu.my',
                'student_id'       => 'CB23037',
                'course'           => 'Bachelor of Computer Science',
                'current_semester' => 'Semester 6',
                'phone_number'     => '017 5744235',
                'personal_advisor' => 'Dr Jamaludin bin Abdullah',
                'address'          => '162A, Jalan Nilam 3, Taman Delima, 08000 Sungai Petani, Kedah',
            ],
            [
                'name'             => 'Ahmad Farhan bin Zulkifli',
                'email'            => 'cb23201@adab.umpsa.edu.my',
                'student_id'       => 'CB23201',
                'course'           => 'Bachelor of Computer Science',
                'current_semester' => 'Semester 4',
            ],
            [
                'name'             => 'Nurul Aina binti Hashim',
                'email'            => 'cb23202@adab.umpsa.edu.my',
                'student_id'       => 'CB23202',
                'course'           => 'Bachelor of Computer Science',
                'current_semester' => 'Semester 4',
            ],
            [
                'name'             => 'Haziq bin Mohd Roslan',
                'email'            => 'cb23203@adab.umpsa.edu.my',
                'student_id'       => 'CB23203',
                'course'           => 'Bachelor of Computer Science',
                'current_semester' => 'Semester 4',
            ],
            [
                'name'             => 'Siti Zulaikha binti Kamarudin',
                'email'            => 'cb22015@adab.umpsa.edu.my',
                'student_id'       => 'CB22015',
                'course'           => 'Bachelor of Computer Science',
                'current_semester' => 'Semester 8',
                'phone_number'     => '011 7823456',
                'personal_advisor' => 'Dr Siti Noor binti Ahmad',
                'address'          => 'No. 5, Lorong Mawar 2, Taman Pelangi, 25200 Kuantan, Pahang',
            ],
            [
                'name'             => 'Mohd Izzat bin Nordin',
                'email'            => 'cb23088@adab.umpsa.edu.my',
                'student_id'       => 'CB23088',
                'course'           => 'Bachelor of Computer Science',
                'current_semester' => 'Semester 4',
                'phone_number'     => '019 2345678',
                'personal_advisor' => 'Dr Faizal bin Hamid',
            ],
            [
                'name'             => 'Wan Nur Izzah binti Wan Ismail',
                'email'            => 'cb24001@adab.umpsa.edu.my',
                'student_id'       => 'CB24001',
                'course'           => 'Bachelor of Computer Science',
                'current_semester' => 'Semester 2',
                'phone_number'     => '013 9876543',
            ],
            [
                'name'             => 'Azrul Hakim bin Mohd Fauzi',
                'email'            => 'cb24055@adab.umpsa.edu.my',
                'student_id'       => 'CB24055',
                'course'           => 'Bachelor of Information Technology',
                'current_semester' => 'Semester 2',
            ],
        ];

        // Create/update users and their Student records
        $users    = [];
        $students = [];
        foreach ($studentData as $data) {
            $matric = $data['student_id'];
            $user   = User::query()->updateOrCreate(
                ['email' => $data['email']],
                array_merge($data, ['role' => 'student', 'password' => Hash::make('123456')])
            );
            $users[$matric] = $user;

            $student = Student::updateOrCreate(
                ['user_id' => $user->id],
                [
                    'matric_number'    => $matric,
                    'program_code'     => 'BCS',
                    'current_semester' => (int) filter_var($data['current_semester'], FILTER_SANITIZE_NUMBER_INT),
                ]
            );
            $students[$matric] = $student;
        }

        // Wipe existing fee & restriction data for these students
        $studentIds = collect($students)->pluck('id');
        Fee::whereIn('student_id', $studentIds)->each(function ($fee) {
            Payment::where('fee_id', $fee->id)->delete();
            $fee->delete();
        });
        Restriction::whereIn('student_id', $studentIds)->delete();

        $sem4 = 'Semester 4 (2025/2026)';
        $sem6 = 'Semester 6 (2025/2026)';
        $sem8 = 'Semester 8 (2024/2025)';
        $sem2 = 'Semester 2 (2025/2026)';

        // ────────────────────────────────────────────────────────────────────
        // CB23037 Muhammad Ammar — fully paid tuition, partial accommodation
        // ────────────────────────────────────────────────────────────────────
        $feeA1 = Fee::create([
            'student_id'         => $students['CB23037']->id,
            'semester'           => $sem6,
            'description'        => 'Tuition Fee',
            'total_amount'       => 1500.00,
            'outstanding_amount' => 1500.00,
            'due_date'           => '2026-03-15',
            'status'             => 'Unpaid',
        ]);
        Payment::create([
            'fee_id'         => $feeA1->id,
            'amount'         => 1500.00,
            'payment_method' => 'online_banking',
            'status'         => 'Success',
            'reference_no'   => 'OB' . strtoupper(Str::random(10)),
            'paid_at'        => now()->subDays(30),
        ]);
        $feeA1->recalculate();

        $feeA2 = Fee::create([
            'student_id'         => $students['CB23037']->id,
            'semester'           => $sem6,
            'description'        => 'Accommodation Fee',
            'total_amount'       => 800.00,
            'outstanding_amount' => 800.00,
            'due_date'           => '2026-03-15',
            'status'             => 'Unpaid',
        ]);
        Payment::create([
            'fee_id'         => $feeA2->id,
            'amount'         => 400.00,
            'payment_method' => 'ewallet',
            'status'         => 'Success',
            'reference_no'   => 'EW' . strtoupper(Str::random(10)),
            'paid_at'        => now()->subDays(15),
        ]);
        $feeA2->recalculate();

        // ────────────────────────────────────────────────────────────────────
        // CB23201 Ahmad Farhan — partial tuition + unpaid activity fee
        // ────────────────────────────────────────────────────────────────────
        $feeB1 = Fee::create([
            'student_id'         => $students['CB23201']->id,
            'semester'           => $sem4,
            'description'        => 'Tuition Fee',
            'total_amount'       => 1200.00,
            'outstanding_amount' => 1200.00,
            'due_date'           => '2026-03-15',
            'status'             => 'Unpaid',
        ]);
        Payment::create([
            'fee_id'         => $feeB1->id,
            'amount'         => 600.00,
            'payment_method' => 'online_banking',
            'status'         => 'Success',
            'reference_no'   => 'OB' . strtoupper(Str::random(10)),
            'paid_at'        => now()->subDays(10),
        ]);
        $feeB1->recalculate();

        Fee::create([
            'student_id'         => $students['CB23201']->id,
            'semester'           => $sem4,
            'description'        => 'Activity & Sports Fee',
            'total_amount'       => 150.00,
            'outstanding_amount' => 150.00,
            'due_date'           => '2026-03-15',
            'status'             => 'Unpaid',
        ]);

        // ────────────────────────────────────────────────────────────────────
        // CB23202 Nurul Aina — fully unpaid + ACTIVE restriction
        // ────────────────────────────────────────────────────────────────────
        Fee::create([
            'student_id'         => $students['CB23202']->id,
            'semester'           => $sem4,
            'description'        => 'Tuition Fee',
            'total_amount'       => 1200.00,
            'outstanding_amount' => 1200.00,
            'due_date'           => '2026-03-15',
            'status'             => 'Unpaid',
        ]);
        Fee::create([
            'student_id'         => $students['CB23202']->id,
            'semester'           => $sem4,
            'description'        => 'Accommodation Fee',
            'total_amount'       => 800.00,
            'outstanding_amount' => 800.00,
            'due_date'           => '2026-03-15',
            'status'             => 'Unpaid',
        ]);
        Restriction::create([
            'student_id'       => $students['CB23202']->id,
            'restriction_type' => 'financial_bar',
            'status'           => 'Active',
            'applied_date'     => Carbon::today()->subDays(5)->toDateString(),
        ]);

        // ────────────────────────────────────────────────────────────────────
        // CB23203 Haziq — all fees fully paid
        // ────────────────────────────────────────────────────────────────────
        $feeD1 = Fee::create([
            'student_id'         => $students['CB23203']->id,
            'semester'           => $sem4,
            'description'        => 'Tuition Fee',
            'total_amount'       => 1200.00,
            'outstanding_amount' => 1200.00,
            'due_date'           => '2026-03-15',
            'status'             => 'Unpaid',
        ]);
        Payment::create([
            'fee_id'         => $feeD1->id,
            'amount'         => 1200.00,
            'payment_method' => 'ewallet',
            'status'         => 'Success',
            'reference_no'   => 'EW' . strtoupper(Str::random(10)),
            'paid_at'        => now()->subDays(20),
        ]);
        $feeD1->recalculate();

        $feeD2 = Fee::create([
            'student_id'         => $students['CB23203']->id,
            'semester'           => $sem4,
            'description'        => 'Activity & Sports Fee',
            'total_amount'       => 150.00,
            'outstanding_amount' => 150.00,
            'due_date'           => '2026-03-15',
            'status'             => 'Unpaid',
        ]);
        Payment::create([
            'fee_id'         => $feeD2->id,
            'amount'         => 150.00,
            'payment_method' => 'cash',
            'status'         => 'Success',
            'reference_no'   => 'CA' . strtoupper(Str::random(10)),
            'paid_at'        => now()->subDays(18),
        ]);
        $feeD2->recalculate();

        // ────────────────────────────────────────────────────────────────────
        // CB22015 Siti Zulaikha — partial tuition, paid lab fee
        // ────────────────────────────────────────────────────────────────────
        $feeE1 = Fee::create([
            'student_id'         => $students['CB22015']->id,
            'semester'           => $sem8,
            'description'        => 'Tuition Fee',
            'total_amount'       => 1800.00,
            'outstanding_amount' => 1800.00,
            'due_date'           => '2026-02-28',
            'status'             => 'Unpaid',
        ]);
        Payment::create([
            'fee_id'         => $feeE1->id,
            'amount'         => 900.00,
            'payment_method' => 'card',
            'status'         => 'Success',
            'reference_no'   => 'CD' . strtoupper(Str::random(10)),
            'paid_at'        => now()->subDays(45),
        ]);
        Payment::create([
            'fee_id'         => $feeE1->id,
            'amount'         => 300.00,
            'payment_method' => 'online_banking',
            'status'         => 'Success',
            'reference_no'   => 'OB' . strtoupper(Str::random(10)),
            'paid_at'        => now()->subDays(14),
        ]);
        $feeE1->recalculate();

        $feeE2 = Fee::create([
            'student_id'         => $students['CB22015']->id,
            'semester'           => $sem8,
            'description'        => 'Lab & Equipment Fee',
            'total_amount'       => 200.00,
            'outstanding_amount' => 200.00,
            'due_date'           => '2026-02-28',
            'status'             => 'Unpaid',
        ]);
        Payment::create([
            'fee_id'         => $feeE2->id,
            'amount'         => 200.00,
            'payment_method' => 'ewallet',
            'status'         => 'Success',
            'reference_no'   => 'EW' . strtoupper(Str::random(10)),
            'paid_at'        => now()->subDays(40),
        ]);
        $feeE2->recalculate();

        // ────────────────────────────────────────────────────────────────────
        // CB23088 Mohd Izzat — had restriction, now LIFTED
        // ────────────────────────────────────────────────────────────────────
        $feeF1 = Fee::create([
            'student_id'         => $students['CB23088']->id,
            'semester'           => $sem4,
            'description'        => 'Tuition Fee',
            'total_amount'       => 1200.00,
            'outstanding_amount' => 1200.00,
            'due_date'           => '2026-03-15',
            'status'             => 'Unpaid',
        ]);
        Payment::create([
            'fee_id'         => $feeF1->id,
            'amount'         => 800.00,
            'payment_method' => 'card',
            'status'         => 'Success',
            'reference_no'   => 'CD' . strtoupper(Str::random(10)),
            'paid_at'        => now()->subDays(3),
        ]);
        $feeF1->recalculate();

        Restriction::create([
            'student_id'       => $students['CB23088']->id,
            'restriction_type' => 'financial_bar',
            'status'           => 'Lifted',
            'applied_date'     => Carbon::today()->subDays(10)->toDateString(),
            'lifted_date'      => Carbon::today()->subDays(3)->toDateString(),
        ]);

        // ────────────────────────────────────────────────────────────────────
        // CB24001 Wan Nur Izzah — fully paid
        // ────────────────────────────────────────────────────────────────────
        $feeG1 = Fee::create([
            'student_id'         => $students['CB24001']->id,
            'semester'           => $sem2,
            'description'        => 'Tuition Fee',
            'total_amount'       => 1000.00,
            'outstanding_amount' => 1000.00,
            'due_date'           => '2026-04-30',
            'status'             => 'Unpaid',
        ]);
        Payment::create([
            'fee_id'         => $feeG1->id,
            'amount'         => 1000.00,
            'payment_method' => 'online_banking',
            'status'         => 'Success',
            'reference_no'   => 'OB' . strtoupper(Str::random(10)),
            'paid_at'        => now()->subDays(7),
        ]);
        $feeG1->recalculate();

        // ────────────────────────────────────────────────────────────────────
        // CB24055 Azrul — new student, fully unpaid
        // ────────────────────────────────────────────────────────────────────
        Fee::create([
            'student_id'         => $students['CB24055']->id,
            'semester'           => $sem2,
            'description'        => 'Tuition Fee',
            'total_amount'       => 1000.00,
            'outstanding_amount' => 1000.00,
            'due_date'           => '2026-04-30',
            'status'             => 'Unpaid',
        ]);
        Fee::create([
            'student_id'         => $students['CB24055']->id,
            'semester'           => $sem2,
            'description'        => 'Activity & Sports Fee',
            'total_amount'       => 120.00,
            'outstanding_amount' => 120.00,
            'due_date'           => '2026-04-30',
            'status'             => 'Unpaid',
        ]);

        // ── Sponsors ────────────────────────────────────────────────────────
        $userIds = collect($users)->pluck('id');
        Sponsor::whereIn('user_id', $userIds)->delete();

        $sponsorData = [
            ['student' => 'CB23037', 'name' => 'JPA (Jabatan Perkhidmatan Awam)', 'type' => 'scholarship', 'coverage' => 'Sem 1 – Sem 8', 'amount' => 2000.00, 'status' => 'active'],
            ['student' => 'CB23037', 'name' => 'PTPTN',                           'type' => 'loan',        'coverage' => null,             'amount' => 0.00,    'status' => 'not_applied'],

            ['student' => 'CB22015', 'name' => 'JPA (Jabatan Perkhidmatan Awam)', 'type' => 'scholarship', 'coverage' => 'Sem 1 – Sem 8', 'amount' => 2000.00, 'status' => 'active'],
            ['student' => 'CB22015', 'name' => 'PTPTN',                           'type' => 'loan',        'coverage' => 'Sem 1 – Sem 8', 'amount' => 3000.00, 'status' => 'active'],

            ['student' => 'CB23201', 'name' => 'MARA',                            'type' => 'scholarship', 'coverage' => 'Sem 1 – Sem 6', 'amount' => 1500.00, 'status' => 'active'],
            ['student' => 'CB23201', 'name' => 'PTPTN',                           'type' => 'loan',        'coverage' => null,             'amount' => 0.00,    'status' => 'not_applied'],

            ['student' => 'CB23202', 'name' => 'PTPTN',                           'type' => 'loan',        'coverage' => 'Sem 1 – Sem 4', 'amount' => 800.00,  'status' => 'active'],
            ['student' => 'CB23202', 'name' => 'JPA (Jabatan Perkhidmatan Awam)', 'type' => 'scholarship', 'coverage' => null,             'amount' => 0.00,    'status' => 'not_applied'],

            ['student' => 'CB23203', 'name' => 'Yayasan Pahang',                  'type' => 'bursary',     'coverage' => 'Sem 1 – Sem 4', 'amount' => 1200.00, 'status' => 'active'],
            ['student' => 'CB23203', 'name' => 'PTPTN',                           'type' => 'loan',        'coverage' => null,             'amount' => 0.00,    'status' => 'not_applied'],

            ['student' => 'CB24001', 'name' => 'PTPTN',                           'type' => 'loan',        'coverage' => null,             'amount' => 0.00,    'status' => 'not_applied'],

            ['student' => 'CB24055', 'name' => 'PTPTN',                           'type' => 'loan',        'coverage' => 'Sem 1 – Sem 8', 'amount' => 1000.00, 'status' => 'active'],
        ];

        foreach ($sponsorData as $s) {
            Sponsor::create([
                'user_id'  => $users[$s['student']]->id,
                'name'     => $s['name'],
                'type'     => $s['type'],
                'coverage' => $s['coverage'],
                'amount'   => $s['amount'],
                'status'   => $s['status'],
            ]);
        }

        $this->command->info('FeeSeeder: 8 students, Student records, fees, restrictions, and sponsors seeded.');
    }
}
