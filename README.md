# PaperPay

PaperPay is a full-stack Newspaper Agency Management ERP built for the Indian market. It features a Flutter app for both Admins and Customers, supported by a Node.js/NeonDB backend.

## Architecture
- **Frontend**: Flutter (Riverpod, Dio, Hive)
- **Backend**: Node.js (Express)
- **Database**: PostgreSQL (Neon Serverless)
- **Authentication**: Firebase Phone Auth

## Features Implemented
- ✅ Customer & Bill Management
- ✅ Subscriptions & Newspaper Master
- ✅ Offline-first Delivery Boy tracking (Sync queues via Hive)
- ✅ Admin Dashboard with Analytics
- ✅ Support/Complaints & Notifications (FCM)
- ✅ Environment-Aware Config (`API_URL` runtime substitution)

## Getting Started

### Backend
1. `cd backend`
2. `npm install`
3. Setup `.env` (DATABASE_URL, PORT)
4. `npm start`

### Flutter App
1. `cd app`
2. `flutter pub get`
3. Generate missing files (if any): `dart run build_runner build`
4. Run: `flutter run --dart-define=API_URL=http://<YOUR_IP>:3000`
