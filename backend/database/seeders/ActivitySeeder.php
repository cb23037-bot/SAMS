<?php

namespace Database\Seeders;

use App\Models\Activity;
use Illuminate\Database\Seeder;

class ActivitySeeder extends Seeder
{
    public function run(): void
    {
        $activities = [
            [
                'name'          => 'Leadership Workshop',
                'code'          => 'LW202',
                'whatsapp_link' => 'https://wa.me/60123456789',
                'description'   => 'A full-day workshop on developing leadership skills, communication, and team management for students aspiring to take on campus roles.',
                'slots' => [
                    ['date' => '2026-07-19', 'time' => '8:00 AM - 5:00 PM', 'capacity' => 30, 'registered' => 20],
                    ['date' => '2026-07-26', 'time' => '8:00 AM - 5:00 PM', 'capacity' => 20, 'registered' => 15],
                ],
            ],
            [
                'name'          => 'Islamic Ethics Seminar',
                'code'          => 'IES305',
                'whatsapp_link' => 'https://wa.me/60198765432',
                'description'   => 'A half-day seminar discussing the application of Islamic ethics and values in modern professional and academic settings.',
                'slots' => [
                    ['date' => '2026-07-10', 'time' => '9:00 AM - 1:00 PM', 'capacity' => 50, 'registered' => 30],
                    ['date' => '2026-08-14', 'time' => '9:00 AM - 1:00 PM', 'capacity' => 50, 'registered' => 8],
                ],
            ],
            [
                'name'          => 'Community Service Programme',
                'code'          => 'CSP101',
                'whatsapp_link' => null,
                'description'   => 'A half-day volunteer community service activity involving gotong-royong and outreach at a local community centre.',
                'slots' => [
                    ['date' => '2026-07-17', 'time' => '8:00 AM - 12:00 PM', 'capacity' => 40, 'registered' => 10],
                    ['date' => '2026-08-07', 'time' => '8:00 AM - 12:00 PM', 'capacity' => 40, 'registered' => 0],
                ],
            ],
            [
                'name'          => 'Public Speaking & Debate',
                'code'          => 'PSD401',
                'whatsapp_link' => 'https://wa.me/60112233445',
                'description'   => 'An intensive programme covering the fundamentals of public speaking, argumentation, and competitive debate. Open to all faculties.',
                'slots' => [
                    ['date' => '2026-07-05', 'time' => '10:00 AM - 4:00 PM', 'capacity' => 25, 'registered' => 25],
                    ['date' => '2026-08-01', 'time' => '10:00 AM - 4:00 PM', 'capacity' => 25, 'registered' => 12],
                ],
            ],
            [
                'name'          => 'Entrepreneurship Bootcamp',
                'code'          => 'EB203',
                'whatsapp_link' => 'https://wa.me/60167788990',
                'description'   => 'A two-session bootcamp guiding students through ideation, business modelling, and pitching a startup idea to a panel of mentors.',
                'slots' => [
                    ['date' => '2026-07-12', 'time' => '9:00 AM - 5:00 PM', 'capacity' => 35, 'registered' => 18],
                    ['date' => '2026-08-22', 'time' => '9:00 AM - 5:00 PM', 'capacity' => 35, 'registered' => 5],
                ],
            ],
            [
                'name'          => 'Mental Health & Wellness Talk',
                'code'          => 'MHW110',
                'whatsapp_link' => null,
                'description'   => 'A talk by a certified counsellor covering stress management, mental resilience, and self-care practices for university students.',
                'slots' => [
                    ['date' => '2026-07-24', 'time' => '2:00 PM - 5:00 PM', 'capacity' => 60, 'registered' => 42],
                ],
            ],
            [
                'name'          => 'Quran Recitation & Tajweed Class',
                'code'          => 'QRT501',
                'whatsapp_link' => 'https://wa.me/60199988776',
                'description'   => 'Weekly sessions on improving Quran recitation using proper Tajweed rules, conducted by a certified Quran teacher.',
                'slots' => [
                    ['date' => '2026-07-06', 'time' => '8:00 AM - 10:00 AM', 'capacity' => 20, 'registered' => 14],
                    ['date' => '2026-07-13', 'time' => '8:00 AM - 10:00 AM', 'capacity' => 20, 'registered' => 16],
                    ['date' => '2026-07-20', 'time' => '8:00 AM - 10:00 AM', 'capacity' => 20, 'registered' => 9],
                ],
            ],
            [
                'name'          => 'Sports & Recreation Day',
                'code'          => 'SRD301',
                'whatsapp_link' => null,
                'description'   => 'An inter-college sports event featuring futsal, badminton, and 3x3 basketball. Participation earns curriculum activity points.',
                'slots' => [
                    ['date' => '2026-08-15', 'time' => '8:00 AM - 6:00 PM', 'capacity' => 100, 'registered' => 57],
                ],
            ],
        ];

        foreach ($activities as $data) {
            $slots = $data['slots'];
            unset($data['slots']);

            $activity = Activity::updateOrCreate(['code' => $data['code']], $data);

            foreach ($slots as $slot) {
                $activity->slots()->updateOrCreate(
                    ['date' => $slot['date'], 'time' => $slot['time']],
                    $slot
                );
            }
        }
    }
}
