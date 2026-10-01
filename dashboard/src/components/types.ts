export type Outlet = {
  id: string;
  name: string;
  phone: string;
  geofence_radius_m: number;
  credit_limit_mad: number;
  latitude?: number | null;
  longitude?: number | null;
  is_active: boolean;
  contact_name?: string | null;
  payment_terms_days?: number | null;
};
