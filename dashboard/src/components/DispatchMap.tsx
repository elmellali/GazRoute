"use client";

import { MapContainer, TileLayer, CircleMarker, Popup } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import { useI18n } from "@/components/LanguageProvider";

const CENTER: [number, number] = [33.5731, -7.5898];

type StopLite = {
  id: string;
  outlet_id: string;
  outlet_name?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  sequence_order: number;
  status: string;
};

const COLORS: Record<string, string> = {
  PENDING: "#94a3b8",
  EN_ROUTE: "#f59e0b",
  NEARBY: "#f97316",
  ARRIVED: "#3b82f6",
  IN_SERVICE: "#8b5cf6",
  COMPLETED: "#22c55e",
  EXCEPTION: "#ef4444",
};

export type LiveVehicle = {
  shift_id: string;
  agent_name: string;
  agent_phone: string;
  plate_number: string;
  vehicle_model?: string | null;
  latitude: number;
  longitude: number;
  speed_kmh?: number | null;
  last_ping_at: string;
  status: string;
};

export default function DispatchMap({
  stops,
  vehicles = [],
}: {
  stops: StopLite[];
  vehicles?: LiveVehicle[];
}) {
  const { t, te } = useI18n();
  return (
    <MapContainer center={CENTER} zoom={12} style={{ height: "100%", width: "100%" }}>
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {stops.map((s, idx) => {
        const lat =
          typeof s.latitude === "number" && !isNaN(s.latitude)
            ? s.latitude
            : CENTER[0] + 0.04 * Math.sin((2 * Math.PI * (idx % 20)) / 20);
        const lng =
          typeof s.longitude === "number" && !isNaN(s.longitude)
            ? s.longitude
            : CENTER[1] + 0.04 * Math.cos((2 * Math.PI * (idx % 20)) / 20);
        return (
          <CircleMarker
            key={s.id}
            center={[lat, lng]}
            radius={8}
            pathOptions={{
              color: COLORS[s.status] || "#3b82f6",
              fillColor: COLORS[s.status] || "#3b82f6",
              fillOpacity: 0.7,
            }}
          >
            <Popup>
              {s.outlet_name ? (
                <>
                  <strong>{s.outlet_name}</strong>
                  <br />
                </>
              ) : null}
              {t("mapStop")} {s.sequence_order}
              <br />
              {t("mapStatus")}: {te(s.status)}
            </Popup>
          </CircleMarker>
        );
      })}
      {vehicles.map((v) => (
        <CircleMarker
          key={v.shift_id}
          center={[v.latitude, v.longitude]}
          radius={12}
          pathOptions={{
            color: "#dc2626",
            fillColor: "#ef4444",
            fillOpacity: 0.9,
            weight: 3,
          }}
        >
          <Popup>
            <div style={{ minWidth: 150 }}>
              <strong style={{ color: "#b91c1c" }}>🚛 {v.plate_number}</strong>
              <br />
              {v.vehicle_model && <span style={{ fontSize: 11, color: "#64748b" }}>{v.vehicle_model}<br /></span>}
              <b>Chauffeur:</b> {v.agent_name}
              <br />
              <b>Vitesse:</b> {v.speed_kmh ? `${v.speed_kmh} km/h` : "À l'arrêt"}
              <br />
              <span style={{ fontSize: 10, color: "#64748b" }}>
                Signal: {new Date(v.last_ping_at).toLocaleTimeString()}
              </span>
            </div>
          </Popup>
        </CircleMarker>
      ))}
    </MapContainer>
  );
}

