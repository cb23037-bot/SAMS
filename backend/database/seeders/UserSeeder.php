<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

class UserSeeder extends Seeder
{
    public function run(): void
    {
        $users = [
            [
                'name'             => 'Pusat Adab',
                'email'            => 'pusatadab@adab.umpsa.edu.my',
                'role'             => 'adab',
                'student_id'       => null,
                'course'           => null,
                'phone_number'     => null,
                'current_semester' => null,
                'personal_advisor' => null,
                'address'          => null,
            ],
            [
                'name'             => 'Treasury Office',
                'email'            => 'treasury@adab.umpsa.edu.my',
                'role'             => 'treasury',
                'student_id'       => null,
                'course'           => null,
                'phone_number'     => null,
                'current_semester' => null,
                'personal_advisor' => null,
                'address'          => null,
            ],
            // ── Semester 6 students ────────────────────────────────────────
            [
                'name'             => 'Muhammad Ammar bin Azizan',
                'email'            => 'cb23037@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB23037',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => '017 5744235',
                'current_semester' => 'Semester 6',
                'personal_advisor' => 'Dr Jamaludin bin Abdullah',
                'address'          => '162A, Jalan Nilam 3, Taman Delima, 08000 Sungai Petani, Kedah',
            ],
            [
                'name'             => 'Muhammad Hizbu Farhan bin Alias',
                'email'            => 'cb23022@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB23022',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => '012 3344556',
                'current_semester' => 'Semester 6',
                'personal_advisor' => 'Dr Jamaludin bin Abdullah',
                'address'          => 'No. 12, Jalan Anggerik 7, Taman Anggerik, 26300 Kuantan, Pahang',
            ],
            [
                'name'             => 'MUHAMMAD AKRAM SYAHMI BIN MOHD SHAM SURI',
                'email'            => 'cb23065@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB23065',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => '016 7788991',
                'current_semester' => 'Semester 6',
                'personal_advisor' => 'Dr Faizal bin Hamid',
                'address'          => 'Blok B-12, Kolej Kediaman 3, UMPSA, 26300 Gambang, Pahang',
            ],
            [
                'name'             => 'STEVE DEMIUS',
                'email'            => 'cb23111@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB23111',
                'course'           => 'Bachelor of Information Technology',
                'phone_number'     => '011 2233445',
                'current_semester' => 'Semester 6',
                'personal_advisor' => 'Dr Siti Noor binti Ahmad',
                'address'          => 'No. 3, Lorong Cempaka 1, Taman Cempaka, 25150 Kuantan, Pahang',
            ],
            // ── Semester 8 student ─────────────────────────────────────────
            [
                'name'             => 'Siti Zulaikha binti Kamarudin',
                'email'            => 'cb22015@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB22015',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => '011 7823456',
                'current_semester' => 'Semester 8',
                'personal_advisor' => 'Dr Siti Noor binti Ahmad',
                'address'          => 'No. 5, Lorong Mawar 2, Taman Pelangi, 25200 Kuantan, Pahang',
            ],
            // ── Semester 4 students ────────────────────────────────────────
            [
                'name'             => 'Ahmad Farhan bin Zulkifli',
                'email'            => 'cb23201@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB23201',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => '013 6677889',
                'current_semester' => 'Semester 4',
                'personal_advisor' => 'Dr Jamaludin bin Abdullah',
                'address'          => 'Blok A-05, Kolej Kediaman 1, UMPSA, 26300 Gambang, Pahang',
            ],
            [
                'name'             => 'Nurul Aina binti Hashim',
                'email'            => 'cb23202@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB23202',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => '014 5566778',
                'current_semester' => 'Semester 4',
                'personal_advisor' => 'Dr Faizal bin Hamid',
                'address'          => 'No. 8, Jalan Kenanga 3, Taman Bunga, 25350 Kuantan, Pahang',
            ],
            [
                'name'             => 'Haziq bin Mohd Roslan',
                'email'            => 'cb23203@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB23203',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => '018 9900112',
                'current_semester' => 'Semester 4',
                'personal_advisor' => 'Dr Jamaludin bin Abdullah',
                'address'          => 'Blok C-22, Kolej Kediaman 2, UMPSA, 26300 Gambang, Pahang',
            ],
            [
                'name'             => 'Mohd Izzat bin Nordin',
                'email'            => 'cb23088@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB23088',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => '019 2345678',
                'current_semester' => 'Semester 4',
                'personal_advisor' => 'Dr Faizal bin Hamid',
                'address'          => 'No. 14, Jalan Dahlia 5, Taman Melor, 25050 Kuantan, Pahang',
            ],
            // ── Semester 2 students ────────────────────────────────────────
            [
                'name'             => 'Wan Nur Izzah binti Wan Ismail',
                'email'            => 'cb24001@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB24001',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => '013 9876543',
                'current_semester' => 'Semester 2',
                'personal_advisor' => 'Dr Siti Noor binti Ahmad',
                'address'          => 'Blok D-07, Kolej Kediaman 4, UMPSA, 26300 Gambang, Pahang',
            ],
            [
                'name'             => 'Azrul Hakim bin Mohd Fauzi',
                'email'            => 'cb24055@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB24055',
                'course'           => 'Bachelor of Information Technology',
                'phone_number'     => '017 1122334',
                'current_semester' => 'Semester 2',
                'personal_advisor' => 'Dr Jamaludin bin Abdullah',
                'address'          => 'No. 2, Jalan Melati 1, Taman Bukit Indah, 26300 Kuantan, Pahang',
            ],
            [
                'name'             => 'Dr Jamaludin bin Abdullah',
                'email'            => 'lecturer@adab.umpsa.edu.my',
                'role'             => 'lecturer',
                'student_id'       => null,
                'course'           => null,
                'phone_number'     => null,
                'current_semester' => null,
                'personal_advisor' => null,
                'address'          => null,
            ],
            [
                'name'             => 'Faculty Registrar',
                'email'            => 'registrar@adab.umpsa.edu.my',
                'role'             => 'faculty_registrar',
                'student_id'       => null,
                'course'           => null,
                'phone_number'     => null,
                'current_semester' => null,
                'personal_advisor' => null,
                'address'          => null,
            ],
        ];

        foreach ($users as $data) {
            User::query()->updateOrCreate(
                ['email' => $data['email']],
                array_merge($data, ['password' => Hash::make('123456')])
            );
        }
    }
}
