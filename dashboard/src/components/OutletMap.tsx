"use client";

import { MapContainer, TileLayer, CircleMarker, Popup } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import type { Outlet } from "./types";
import { useI18n } from "@/components/LanguageProvider";

// Casablanca default center
const CENTER: [number, number] = [33.5731, -7.5898];

export default function OutletMap({
  outlets,
  onSelect,
}: {
  outlets: Outlet[];
  onSelect: (o: Outlet) => void;
}) {
  const { t } = useI18n();
  return (
    <MapContainer center={CENTER} zoom={12} style={{ height: "100%", width: "100%" }}>
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {outlets.map((o, idx) => {
        const lat =
          typeof o.latitude === "number" && !isNaN(o.latitude)
            ? o.latitude
            : CENTER[0] + 0.04 * Math.sin((2 * Math.PI * idx) / Math.max(outlets.length, 1));
        const lng =
          typeof o.longitude === "number" && !isNaN(o.longitude)
            ? o.longitude
            : CENTER[1] + 0.04 * Math.cos((2 * Math.PI * idx) / Math.max(outlets.length, 1));
        return (
          <CircleMarker
            key={o.id}
            center={[lat, lng]}
            radius={Math.max(6, o.geofence_radius_m / 10)}
            pathOptions={{ color: "#3b82f6", fillOpacity: 0.35 }}
            eventHandlers={{ click: () => onSelect(o) }}
          >
            <Popup>
              <strong>{o.name}</strong>
              <br />
              {o.phone}
              <br />
              {t("limitLabel")}: {o.credit_limit_mad} MAD
            </Popup>
          </CircleMarker>
        );
      })}
    </MapContainer>
  );
}
