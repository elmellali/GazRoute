import os
from decimal import Decimal
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from geoalchemy2.elements import WKTElement
from app.models.entities import Tenant, User, InventoryLocation, CylinderType, Vehicle, Outlet
from app.core.security import hash_password

def seed_database():
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("DATABASE_URL not set, skipping seed.")
        return
        
    engine = create_engine(db_url)
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        # Check if tenant exists
        if session.query(Tenant).first():
            print("Database already seeded. Skipping.")
            return
            
        print("Seeding database with default demo accounts...")
        
        # 1. Tenant
        tenant = Tenant(company_name="Gaz Distribution Demo", phone="+212600000000")
        session.add(tenant)
        session.flush()

        # 2. Users (Phones match the React dashboard demo buttons)
        users = [
            User(tenant_id=tenant.id, phone="+212600000001", full_name="Admin Owner", role="owner", password_hash=hash_password("Passw0rd!")),
            User(tenant_id=tenant.id, phone="+212600000002", full_name="Warehouse Manager", role="warehouse", password_hash=hash_password("Passw0rd!")),
            User(tenant_id=tenant.id, phone="+212600000003", full_name="Dispatcher", role="dispatcher", password_hash=hash_password("Passw0rd!")),
            User(tenant_id=tenant.id, phone="+212600000004", full_name="Field Agent", role="agent", password_hash=hash_password("Passw0rd!")),
            User(tenant_id=tenant.id, phone="+212600000005", full_name="Accountant", role="accountant", password_hash=hash_password("Passw0rd!")),
        ]
        session.add_all(users)
        session.flush()
        
        # 3. Base Entities
        depot = InventoryLocation(tenant_id=tenant.id, name="Dépôt Central Casa", type="depot")
        session.add(depot)
        
        ct1 = CylinderType(tenant_id=tenant.id, gas_type="butane", size_kg=Decimal("12.00"), deposit_amount_mad=Decimal("100"), base_sale_price_mad=Decimal("40"))
        ct2 = CylinderType(tenant_id=tenant.id, gas_type="butane", size_kg=Decimal("3.00"), deposit_amount_mad=Decimal("50"), base_sale_price_mad=Decimal("12"))
        session.add_all([ct1, ct2])
        
        veh = Vehicle(tenant_id=tenant.id, plate_number="1234-A-50", model="Isuzu NQR")
        session.add(veh)
        
        outlet = Outlet(tenant_id=tenant.id, name="Hanout Al Baraka", phone="+212611111111", location=WKTElement("POINT(-7.5998 33.5831)", srid=4326))
        session.add(outlet)
        
        session.flush()
        
        ol = InventoryLocation(tenant_id=tenant.id, name="Hanout Al Baraka", type="outlet", reference_id=outlet.id)
        session.add(ol)
        
        session.commit()
        print("Database seed completed successfully!")
        
    except Exception as e:
        session.rollback()
        print(f"Error during seeding: {e}")
    finally:
        session.close()

if __name__ == "__main__":
    seed_database()
