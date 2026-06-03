# SAMS — Student Activity Management System

A mobile and web application for managing co-curricular activities and student credit claims at **UMPSA (Universiti Malaysia Pahang Al-Sultan Abdullah)**.

---

## Overview

SAMS streamlines the Ko-Kurikulum (KoQ) activity workflow between students and Pusat Adab staff:

- **Students** register for activities, submit attendance via selfie + GPS, and claim co-curricular credits with proof uploads.
- **Pusat Adab Staff** manage activities and time slots, control student access periods, and review/approve credit claims.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Backend API | Laravel 10 (PHP 8.1+) |
| Database | MySQL |
| Authentication | Laravel Sanctum (token-based) |
| Frontend | Flutter (Dart 3.11+) |
| Platforms | Android, iOS, Web |

---

## Project Structure

```
SAMS/
├── backend/                    # Laravel REST API
│   ├── app/
│   │   ├── Http/Controllers/Api/
│   │   └── Models/
│   ├── database/
│   │   └── migrations/
│   └── routes/
│       └── api.php
│
└── frontend/                   # Flutter Application
    └── lib/
        ├── main.dart
        ├── pages/
        │   
        └── services/
            └── api_service.dart
```

---

## Features

### Student
- Register and unregister from KoQ activity slots
- Submit attendance using attendance code, selfie photo, and GPS location
- Upload proof and submit credit claims
- View registration history and claim status
- Receive notifications on claim approval/rejection

### Pusat Adab (Admin)
- Create, update, and delete activities and time slots
- Open or close student registration and claim access
- Review pending credit claims with student proof
- Approve or reject claims with remarks/reasons
- View activity attendance records

---

## Getting Started

### Prerequisites

- PHP 8.1+
- Composer
- MySQL
- Flutter SDK 3.11+
- Android Studio / VS Code

---

### Backend Setup

```bash
cd backend

# Install dependencies
composer install

# Copy environment file
cp .env.example .env

# Generate application key
php artisan key:generate

# Configure database in .env
# DB_DATABASE=sams_db
# DB_USERNAME=root
# DB_PASSWORD=

# Run migrations
php artisan migrate

# Start development server
php artisan serve
```

---

### Frontend Setup

```bash
cd frontend

# Install Flutter dependencies
flutter pub get

# Run the app
flutter run
```

> Make sure to update the API base URL in `lib/services/api_service.dart` to match your backend server address.

---

## API Endpoints

### Public
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/login` | Authenticate user |

### Authenticated (All Users)
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/logout` | Logout |
| PUT | `/api/profile` | Update profile |
| GET | `/api/activities` | List all activities with slots |

### Student Only
| Method | Endpoint | Description |
|---|---|---|
| GET | `/api/student/access` | Check if registration/claims are open |
| GET | `/api/student/registrations` | List registrations |
| POST | `/api/student/registrations` | Register for a slot |
| DELETE | `/api/student/registrations/{id}` | Cancel registration |
| POST | `/api/student/registrations/{id}/claim` | Submit credit claim |
| DELETE | `/api/student/registrations/{id}/claim` | Withdraw claim |
| POST | `/api/student/attendances` | Submit attendance |

### Pusat Adab Only
| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/activities` | Create activity |
| PUT | `/api/activities/{id}` | Update activity |
| DELETE | `/api/activities/{id}` | Delete activity |
| POST | `/api/activities/{id}/slots` | Add slot |
| DELETE | `/api/activities/{id}/slots/{slot}` | Remove slot |
| GET/PUT | `/api/adab/access` | Get/set student access |
| GET | `/api/adab/claims` | List all claims |
| PUT | `/api/adab/claims/{id}/approve` | Approve claim |
| PUT | `/api/adab/claims/{id}/reject` | Reject claim |

---

## Database Schema

| Table | Description |
|---|---|
| `users` | Students and Pusat Adab staff accounts |
| `activities` | KoQ activity records with CATS credits |
| `activity_slots` | Date/time slots for each activity |
| `activity_registrations` | Student registrations and claim status |
| `attendance_submissions` | Attendance records with photo and GPS |
| `settings` | System-wide access control flags |

---

## User Roles

| Role | Access |
|---|---|
| `student` | Register activities, submit attendance, claim credits |
| `adab` | Manage activities, review and process claims |

> Login is restricted to `@adab.umpsa.edu.my` email domain for Pusat Adab staff.

---

## License

This project is developed for academic purposes at UMPSA.
