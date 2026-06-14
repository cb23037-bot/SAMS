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
                'name'             => 'Muhammad izbu Farhan bin Alias',
                'email'            => 'cb23022@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB23022',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => null,
                'current_semester' => 'Semester 6',
                'personal_advisor' => null,
                'address'          => null,
            ],
            [
                'name'             => 'MUHAMMAD AKRAM SYAHMI BIN MOHD SHAM SURI',
                'email'            => 'cb23065@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB23065',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => null,
                'current_semester' => 'Semester 6',
                'personal_advisor' => null,
                'address'          => null,
            ],
            [
                'name'             => 'STEVE DEMIUS',
                'email'            => 'cb23111@adab.umpsa.edu.my',
                'role'             => 'student',
                'student_id'       => 'CB23111',
                'course'           => 'Bachelor of Computer Science',
                'phone_number'     => null,
                'current_semester' => 'Semester 6',
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
