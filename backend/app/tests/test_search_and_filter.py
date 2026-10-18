from decimal import Decimal
import uuid
from fastapi.testclient import TestClient

from app.core.database import SessionLocal
from app.core.security import hash_password
from app.main import app
from app.models.property import Property
from app.models.room import Room
from app.models.user import User

client = TestClient(app)


def create_owner() -> User:
    db = SessionLocal()
    try:
        owner = User(
            name="Search Test Owner",
            email=f"owner_{uuid.uuid4().hex[:8]}@example.com",
            password_hash=hash_password("ownerPass123"),
            role="owner",
        )
        db.add(owner)
        db.commit()
        db.refresh(owner)
        return owner
    finally:
        db.close()


def test_search_by_title_description_city_address_and_case_insensitive():
    owner = create_owner()
    unique_tag = uuid.uuid4().hex[:6]
    db = SessionLocal()
    try:
        p1 = Property(
            owner_id=owner.id,
            title=f"Galaxy Residency {unique_tag}",
            description="Close to Metro station with great study desks",
            property_type="pg",
            address="Sector 62 Phase 2",
            city=f"Noida_{unique_tag}",
            is_verified=True,
            is_available=True,
        )
        p2 = Property(
            owner_id=owner.id,
            title=f"Green Villa {unique_tag}",
            description="Spacious hostel with garden area",
            property_type="hostel",
            address="Golf Course Ext Road",
            city=f"Gurugram_{unique_tag}",
            is_verified=True,
            is_available=True,
        )
        db.add_all([p1, p2])
        db.commit()
        db.refresh(p1)
        db.refresh(p2)
        p1_id, p2_id = p1.id, p2.id
    finally:
        db.close()

    # Search by title (case-insensitive)
    res = client.get(f"/properties?q=GALAXY&city=Noida_{unique_tag}")
    assert res.status_code == 200
    data = res.json()
    assert data["total"] == 1
    assert data["items"][0]["id"] == p1_id

    # Search by description (case-insensitive)
    res_desc = client.get(f"/properties?q=metro&city=Noida_{unique_tag}")
    assert res_desc.status_code == 200
    assert res_desc.json()["total"] == 1
    assert res_desc.json()["items"][0]["id"] == p1_id

    # Search by address
    res_addr = client.get(f"/properties?q=golf course&city=Gurugram_{unique_tag}")
    assert res_addr.status_code == 200
    assert res_addr.json()["total"] == 1
    assert res_addr.json()["items"][0]["id"] == p2_id

    # Search with no match
    res_none = client.get(f"/properties?q=nonexistentkeyword123&city=Noida_{unique_tag}")
    assert res_none.status_code == 200
    assert res_none.json()["total"] == 0
    assert res_none.json()["items"] == []


def test_rent_and_sharing_type_filters():
    owner = create_owner()
    unique_city = f"RentCity_{uuid.uuid4().hex[:6]}"
    db = SessionLocal()
    try:
        # Property A: Room 1 (8000), Room 2 (5000)
        pA = Property(
            owner_id=owner.id,
            title="Property A",
            property_type="pg",
            address="A St",
            city=unique_city,
            is_verified=True,
            is_available=True,
        )
        # Property B: Room 3 (3500)
        pB = Property(
            owner_id=owner.id,
            title="Property B",
            property_type="hostel",
            address="B St",
            city=unique_city,
            is_verified=True,
            is_available=True,
        )
        # Property C: Room 4 (12000)
        pC = Property(
            owner_id=owner.id,
            title="Property C",
            property_type="flat",
            address="C St",
            city=unique_city,
            is_verified=True,
            is_available=True,
        )
        # Property D: Room 5 (3000) and Room 6 (10000) -> split rents (neither room is 5000-7000)
        pD = Property(
            owner_id=owner.id,
            title="Property D Split",
            property_type="pg",
            address="D St",
            city=unique_city,
            is_verified=True,
            is_available=True,
        )
        db.add_all([pA, pB, pC, pD])
        db.commit()

        r1 = Room(property_id=pA.id, sharing_type="single", monthly_rent=Decimal("8000.00"), available_beds=1)
        r2 = Room(property_id=pA.id, sharing_type="double", monthly_rent=Decimal("5000.00"), available_beds=2)
        r3 = Room(property_id=pB.id, sharing_type="triple", monthly_rent=Decimal("3500.00"), available_beds=3)
        r4 = Room(property_id=pC.id, sharing_type="single", monthly_rent=Decimal("12000.00"), available_beds=1)
        r5 = Room(property_id=pD.id, sharing_type="triple", monthly_rent=Decimal("3000.00"), available_beds=3)
        r6 = Room(property_id=pD.id, sharing_type="single", monthly_rent=Decimal("10000.00"), available_beds=1)
        db.add_all([r1, r2, r3, r4, r5, r6])
        db.commit()

        pA_id, pB_id, pC_id, pD_id = pA.id, pB.id, pC.id, pD.id
    finally:
        db.close()

    # 1. min_rent = 7000 -> Should match Property A (room 8000), Property C (room 12000), Property D (room 10000)
    res_min = client.get(f"/properties?city={unique_city}&min_rent=7000")
    assert res_min.status_code == 200
    ids_min = [item["id"] for item in res_min.json()["items"]]
    assert pA_id in ids_min
    assert pC_id in ids_min
    assert pD_id in ids_min
    assert pB_id not in ids_min

    # 2. max_rent = 4000 -> Should match Property B (3500), Property D (3000)
    res_max = client.get(f"/properties?city={unique_city}&max_rent=4000")
    assert res_max.status_code == 200
    ids_max = [item["id"] for item in res_max.json()["items"]]
    assert pB_id in ids_max
    assert pD_id in ids_max
    assert pA_id not in ids_max
    assert pC_id not in ids_max

    # 3. Combined min_rent=4500 & max_rent=6000:
    # Must be satisfied by the SAME room!
    # Prop A has room 2 (5000) which satisfies 4500 <= rent <= 6000.
    # Prop D has rooms at 3000 and 10000 (neither room is between 4500 and 6000).
    res_comb = client.get(f"/properties?city={unique_city}&min_rent=4500&max_rent=6000")
    assert res_comb.status_code == 200
    ids_comb = [item["id"] for item in res_comb.json()["items"]]
    assert ids_comb == [pA_id]

    # 4. Filter by sharing_type="single"
    res_share = client.get(f"/properties?city={unique_city}&sharing_type=single")
    assert res_share.status_code == 200
    ids_share = [item["id"] for item in res_share.json()["items"]]
    assert pA_id in ids_share
    assert pC_id in ids_share
    assert pD_id in ids_share
    assert pB_id not in ids_share

    # 5. Combined sharing_type="double" and max_rent=6000
    res_share_rent = client.get(f"/properties?city={unique_city}&sharing_type=double&max_rent=6000")
    assert res_share_rent.status_code == 200
    ids_share_rent = [item["id"] for item in res_share_rent.json()["items"]]
    assert ids_share_rent == [pA_id]


def test_invalid_rent_parameters_return_422():
    # Negative min_rent
    res1 = client.get("/properties?min_rent=-500")
    assert res1.status_code == 422

    # Negative max_rent
    res2 = client.get("/properties?max_rent=-100")
    assert res2.status_code == 422

    # min_rent > max_rent
    res3 = client.get("/properties?min_rent=8000&max_rent=4000")
    assert res3.status_code == 422
    assert res3.json()["detail"] == "min_rent cannot exceed max_rent"


def test_sorting_and_duplicate_prevention():
    owner = create_owner()
    sort_city = f"SortCity_{uuid.uuid4().hex[:6]}"
    db = SessionLocal()
    try:
        p_cheap = Property(
            owner_id=owner.id,
            title="Cheap Stay",
            property_type="pg",
            address="1 St",
            city=sort_city,
            is_verified=True,
            is_available=True,
        )
        p_mid = Property(
            owner_id=owner.id,
            title="Mid Stay",
            property_type="pg",
            address="2 St",
            city=sort_city,
            is_verified=True,
            is_available=True,
        )
        p_luxury = Property(
            owner_id=owner.id,
            title="Luxury Stay",
            property_type="pg",
            address="3 St",
            city=sort_city,
            is_verified=True,
            is_available=True,
        )
        p_noroom = Property(
            owner_id=owner.id,
            title="No Room Stay",
            property_type="pg",
            address="4 St",
            city=sort_city,
            is_verified=True,
            is_available=True,
        )
        db.add_all([p_cheap, p_mid, p_luxury, p_noroom])
        db.commit()

        # Add multiple rooms to p_cheap to verify no duplicate rows occur
        r1 = Room(property_id=p_cheap.id, sharing_type="double", monthly_rent=Decimal("3000.00"), available_beds=2)
        r2 = Room(property_id=p_cheap.id, sharing_type="single", monthly_rent=Decimal("4000.00"), available_beds=1)
        r3 = Room(property_id=p_mid.id, sharing_type="single", monthly_rent=Decimal("6000.00"), available_beds=1)
        r4 = Room(property_id=p_luxury.id, sharing_type="single", monthly_rent=Decimal("15000.00"), available_beds=1)
        db.add_all([r1, r2, r3, r4])
        db.commit()

        cheap_id, mid_id, luxury_id, noroom_id = p_cheap.id, p_mid.id, p_luxury.id, p_noroom.id
    finally:
        db.close()

    # Sort rent_low_to_high
    res_low = client.get(f"/properties?city={sort_city}&sort_by=rent_low_to_high")
    assert res_low.status_code == 200
    ids_low = [item["id"] for item in res_low.json()["items"]]
    # Should order: Cheap (3000) -> Mid (6000) -> Luxury (15000) -> No Room (NULL last)
    assert ids_low == [cheap_id, mid_id, luxury_id, noroom_id]
    # Verify no duplicates even though Cheap has 2 rooms
    assert len(ids_low) == len(set(ids_low))

    # Sort rent_high_to_low
    res_high = client.get(f"/properties?city={sort_city}&sort_by=rent_high_to_low")
    assert res_high.status_code == 200
    ids_high = [item["id"] for item in res_high.json()["items"]]
    assert ids_high == [luxury_id, mid_id, cheap_id, noroom_id]

    # Invalid sort_by returns 422
    res_inv = client.get(f"/properties?city={sort_city}&sort_by=invalid_sort")
    assert res_inv.status_code == 422


def test_pagination_and_max_page_size_enforcement():
    owner = create_owner()
    pag_city = f"PagCity_{uuid.uuid4().hex[:6]}"
    db = SessionLocal()
    try:
        props = [
            Property(
                owner_id=owner.id,
                title=f"Pag Stay {i}",
                property_type="pg",
                address=f"{i} Street",
                city=pag_city,
                is_verified=True,
                is_available=True,
            )
            for i in range(5)
        ]
        db.add_all(props)
        db.commit()
    finally:
        db.close()

    # Request page 1 with page_size=2
    res_p1 = client.get(f"/properties?city={pag_city}&page=1&page_size=2")
    assert res_p1.status_code == 200
    d1 = res_p1.json()
    assert len(d1["items"]) == 2
    assert d1["page"] == 1
    assert d1["page_size"] == 2
    assert d1["total"] == 5

    # Request page 2 with page_size=2
    res_p2 = client.get(f"/properties?city={pag_city}&page=2&page_size=2")
    assert res_p2.status_code == 200
    d2 = res_p2.json()
    assert len(d2["items"]) == 2
    assert d2["page"] == 2

    # Enforce max page size of 50 (page_size > 50 returns 422)
    res_over = client.get(f"/properties?page_size=51")
    assert res_over.status_code == 422

    # page < 1 returns 422
    assert client.get("/properties?page=0").status_code == 422


def test_visibility_rules_with_search_and_filters():
    owner = create_owner()
    v_city = f"VisCity_{uuid.uuid4().hex[:6]}"
    secret_term = f"SecretKeyword_{uuid.uuid4().hex[:6]}"
    db = SessionLocal()
    try:
        # 1. Verified and available (VISIBLE)
        p_vis = Property(
            owner_id=owner.id,
            title=f"Visible Stay {secret_term}",
            property_type="pg",
            address="1 St",
            city=v_city,
            is_verified=True,
            is_available=True,
        )
        # 2. Unverified (HIDDEN)
        p_unver = Property(
            owner_id=owner.id,
            title=f"Unverified Stay {secret_term}",
            property_type="pg",
            address="2 St",
            city=v_city,
            is_verified=False,
            is_available=True,
        )
        # 3. Unavailable (HIDDEN)
        p_unavail = Property(
            owner_id=owner.id,
            title=f"Unavailable Stay {secret_term}",
            property_type="pg",
            address="3 St",
            city=v_city,
            is_verified=True,
            is_available=False,
        )
        db.add_all([p_vis, p_unver, p_unavail])
        db.commit()
        vis_id = p_vis.id
    finally:
        db.close()

    res = client.get(f"/properties?q={secret_term}")
    assert res.status_code == 200
    data = res.json()
    # Total count and items must ONLY include the visible property
    assert data["total"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["id"] == vis_id
