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
                'name'             => 'Dr Jamaludin bin Abdullah',
                'email'            => 'jamaludin@adab.umpsa.edu.my',
                'role'             => 'lecturer',
                'student_id'       => null,
                'course'           => null,
                'phone_number'     => '012 3456789',
                'current_semester' => null,
                'personal_advisor' => null,
                'address'          => 'Office 216, Building C',
            ],
            [
                'name'             => 'Faculty Registrar',
                'email'            => 'facultyregistrar@adab.umpsa.edu.my',
                'role'             => 'facultyregistrar',
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
                'name'             => 'Student CB23022',
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
                'name'             => 'Student CB23065',
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
                'name'             => 'Student CB23111',
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
