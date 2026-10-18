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
- **Authentication:** JWT (PyJWT) & Argon2 password hashing
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
- **Phase 3: Authentication & Security**
  - Argon2 password hashing and verification.
  - User registration (`POST /auth/register`) with secure student-only public role assignment.
  - User login (`POST /auth/login`) generating signed JWT access tokens.
  - Current user dependency and protected profile endpoint (`GET /auth/me`).
- **Phase 4: Accommodation Database Design**
  - Designed and implemented SQLAlchemy 2.x models: `Property`, `Room`, `Amenity`, `PropertyImage`, and `property_amenities` (association table).
  - Configured foreign keys with cascade deletions and check constraints for financial/inventory integrity (`monthly_rent`, `security_deposit`, `available_beds`).
- **Phase 5: Property CRUD APIs**
  - Implemented Property CRUD endpoints: `POST /properties`, `GET /properties`, `GET /properties/{id}`, `PATCH /properties/{id}`, `DELETE /properties/{id}`.
  - Enforced strict authorization: only owners can create properties; only owning user or admin can update/delete.
  - Public listing and detail endpoints filter for verified & available properties, with pagination and eager-loading (`selectinload`) to prevent N+1 queries.
- **Phase 6: Search, Filtering, Sorting & Pagination**
  - Text search query (`q`) across title, description, city, and address with case-insensitive matching (`ilike`).
  - Accommodation filtering by `city`, `property_type`, `sharing_type`, and rent bounds (`min_rent`, `max_rent`) applied consistently to the same room via `EXISTS` subqueries to avoid duplicate records.
  - Deterministic sorting via `sort_by` (`newest`, `rent_low_to_high`, `rent_high_to_low`) with secondary ID tie-breaker.
  - Safe pagination with `page`, `page_size` (enforced max 50), and accurate total count calculation preserving public visibility rules (`is_available = true`, `is_verified = true`).
- **Phase 7: Maps, Exact Property Location & Google Maps Directions**
  - Owner exact property location selection on interactive OpenStreetMap (`flutter_map` + `latlong2`) with draggable/tappable marker and coordinate validation.
  - Backend validation for latitude (-90 to 90) and longitude (-180 to 180), required for new properties while preserving backward compatibility with legacy listings.
  - Haversine distance calculation and radius filtering (`latitude`, `longitude`, `radius_km`) with distance sorting (`sort_by=distance`) and returned `distance_km`.
  - Student map exploration screen with property markers, preview cards, and navigation to property details.
  - One-tap Google Maps directions via `url_launcher` using the official directions URL format with external app and browser fallback.
- **Phase 8A: Supabase Storage Integration**
  - Configured Supabase Storage credentials (`SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `SUPABASE_STORAGE_BUCKET`) in backend environment and settings.
  - Added `supabase>=2.0.0` dependency without modifying PostgreSQL database connection.
  - Created backend storage utility (`storage.py`) enforcing 5 MB size limit, strict MIME validation (`image/jpeg`, `image/png`, `image/webp`), and server-side unique path generation (`properties/{property_id}/{uuid}.{ext}`).
  - Linked storage operations to existing `PropertyImage` model and PostgreSQL metadata persistence.
  - Verified with 10 focused unit tests covering file validation, path generation, mocked cloud operations, and database persistence.
- **Phase 8B: Property Image Upload and Delete APIs**
  - Created Alembic migration adding `storage_path` to `property_images` table with safe backward-compatible defaults.
  - Implemented `POST /properties/{property_id}/images` accepting `multipart/form-data`, validating binary magic bytes (JPEG/PNG/WebP), enforcing 5 MB limit, uploading to Supabase, and saving metadata.
  - Implemented `DELETE /properties/{property_id}/images/{image_id}` verifying property-image ownership and safely removing the object from Supabase and record from PostgreSQL.
  - Implemented atomic orphan rollback: storage uploads are cleaned up if database persistence fails.
  - Live verified upload and delete operations against the configured Supabase bucket `property-images`.
  - Added 14 unit and integration tests covering authorization, content validation, size limits, failure cleanups, and property details serialization.




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
