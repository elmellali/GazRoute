import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.models.entities import Tenant, User, DepotLocation, CylinderType, Vehicle, Outlet, PricingMatrix
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
        depot = DepotLocation(tenant_id=tenant.id, name="Dépôt Central Casa", latitude=33.5731, longitude=-7.5898, type="warehouse")
        session.add(depot)
        
        ct1 = CylinderType(tenant_id=tenant.id, name="Butane 12kg", brand="Afriquia", current_deposit_fee_mad=100.0)
        ct2 = CylinderType(tenant_id=tenant.id, name="Butane 3kg", brand="Afriquia", current_deposit_fee_mad=50.0)
        session.add_all([ct1, ct2])
        
        veh = Vehicle(tenant_id=tenant.id, license_plate="1234-A-50", type="truck", capacity_kg=5000.0, current_depot_id=depot.id)
        session.add(veh)
        
        outlet = Outlet(tenant_id=tenant.id, name="Hanout Al Baraka", phone="+212611111111", latitude=33.5831, longitude=-7.5998, address="Bd Anfa, Casa")
        session.add(outlet)
        
        session.flush()
        
        # 4. Pricing Matrix
        pm1 = PricingMatrix(tenant_id=tenant.id, outlet_id=outlet.id, cylinder_type_id=ct1.id, override_price_mad=40.0)
        pm2 = PricingMatrix(tenant_id=tenant.id, outlet_id=outlet.id, cylinder_type_id=ct2.id, override_price_mad=10.0)
        session.add_all([pm1, pm2])
        
        session.commit()
        print("Database seed completed successfully!")
        
    except Exception as e:
        session.rollback()
        print(f"Error during seeding: {e}")
    finally:
        session.close()

if __name__ == "__main__":
    seed_database()
