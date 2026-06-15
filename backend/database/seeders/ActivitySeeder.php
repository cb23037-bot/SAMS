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
                'description'   => 'Workshop on developing leadership skills for students',
                'slots' => [
                    ['date' => '2026-04-19', 'time' => '8:00 AM - 5:00 PM', 'capacity' => 30, 'registered' => 20],
                    ['date' => '2026-04-26', 'time' => '8:00 AM - 5:00 PM', 'capacity' => 20, 'registered' => 15],
                ],
            ],
            [
                'name'          => 'Islamic Ethics Seminar',
                'code'          => 'IES305',
                'whatsapp_link' => 'https://wa.me/60198765432',
                'description'   => 'Seminar discussing Islamic ethics in modern society',
                'slots' => [
                    ['date' => '2026-05-10', 'time' => '9:00 AM - 1:00 PM', 'capacity' => 50, 'registered' => 30],
                ],
            ],
            [
                'name'          => 'Community Service Programme',
                'code'          => 'CSP101',
                'whatsapp_link' => null,
                'description'   => 'Volunteer community service activities for students',
                'slots' => [
                    ['date' => '2026-05-17', 'time' => '8:00 AM - 12:00 PM', 'capacity' => 40, 'registered' => 10],
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
