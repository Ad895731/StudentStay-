# StudentStay

StudentStay is a modern student accommodation discovery and verification platform designed to simplify finding trusted housing near colleges and coaching institutes.

---

## 📌 Problem

Students relocating to a new city for college, coaching, internships, or jobs frequently struggle to find affordable, safe, and trustworthy rooms, PGs, and hostels near their destination. Common challenges include:
- Lack of verified property details and authentic student reviews.
- Lack of transparent pricing, sharing configurations, food options, and amenities.
- Inefficient search and discovery mechanisms without map visualizations or commute distance indicators.

---

## 💡 Solution

StudentStay provides a discovery experience tailored specifically to student housing:
- **Search & Filtering:** Search by city, college/institute, budget, commute distance, room sharing type, food availability, and key amenities.
- **Verification & Reviews:** Clear verification badges, photo galleries, and genuine peer reviews.
- **Interactive Exploration:** Map-based view for locating stays near campus.
- **Engagement:** Shortlisting, in-app owner inquiries, and visit scheduling.
- **Role-Based Workflows:** Distinct portals and permissions for Students, Property Owners, and Platform Administrators.

---

## 🛠️ Current Tech Stack

- **Frontend:** Flutter & Dart (Cross-platform: Mobile, Web, Desktop)
- **Backend:** FastAPI (Python)
- **Database:** PostgreSQL
- **ORM:** SQLAlchemy 2.x
- **Migrations:** Alembic
- **Authentication:** JWT *(planned)*
- **Testing:** pytest (Backend) / Flutter test (Frontend)
- **Additional (Upcoming Phases):** Redis (caching), Maps API (mapping & routing), Cloud Object Storage (photos/documents), Docker (containerization)

---

## 🚀 Current Development Status

- **Phase 1: Project Initialization & Foundation**
  - Modular FastAPI backend & Flutter frontend structure established.
  - Health endpoint (`GET /health`) implemented and verified.
- **Phase 2: Database Foundation**
  - PostgreSQL database connection configured with SQLAlchemy 2.x engine and sessionmaker.
  - Initial `User` database model created using DeclarativeBase mapped columns.
  - Alembic migration environment initialized and migration applied for the `users` table.


---

## 📂 Project Structure

```text
StudentStay/
├── frontend/             # Flutter client application
│   ├── lib/
│   ├── test/
│   └── pubspec.yaml
├── backend/              # FastAPI backend service
│   ├── app/
│   │   ├── core/         # Config and settings
│   │   ├── models/       # Database models
│   │   ├── routers/      # API endpoints & route handlers
│   │   ├── schemas/      # Pydantic validation schemas
│   │   ├── services/     # Business logic
│   │   ├── tests/        # Pytest test cases
│   │   └── main.py       # FastAPI application entrypoint
│   └── requirements.txt  # Python package dependencies
└── README.md             # Project documentation
```
