"use client";

import { useEffect, useState } from "react";
import { MapContainer, TileLayer, Marker, useMapEvents } from "react-leaflet";
import "leaflet/dist/leaflet.css";
import L from "leaflet";

// Fix Leaflet's default icon path issues with Next.js
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png",
  iconUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png",
  shadowUrl: "https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png",
});

function LocationMarker({
  position,
  setPosition,
}: {
  position: [number, number];
  setPosition: (pos: [number, number]) => void;
}) {
  const map = useMapEvents({
    click(e) {
      setPosition([e.latlng.lat, e.latlng.lng]);
    },
  });

  return position === null ? null : (
    <Marker position={position} />
  );
}

export default function LocationPickerMap(props: {
  latitude?: number;
  longitude?: number;
  initialLat?: number;
  initialLng?: number;
  onLocationChange?: (lat: number, lng: number) => void;
  onLocationSelect?: (lat: number, lng: number) => void;
}) {
  const rawLat = props.latitude ?? props.initialLat;
  const rawLng = props.longitude ?? props.initialLng;
  const safeLat = typeof rawLat === "number" && !isNaN(rawLat) ? rawLat : 33.5731;
  const safeLng = typeof rawLng === "number" && !isNaN(rawLng) ? rawLng : -7.5898;

  const callback = props.onLocationChange || props.onLocationSelect;

  const [position, setPosition] = useState<[number, number]>([safeLat, safeLng]);

  useEffect(() => {
    if (position[0] !== safeLat || position[1] !== safeLng) {
      if (callback) callback(position[0], position[1]);
    }
  }, [position, safeLat, safeLng, callback]);

  useEffect(() => {
    setPosition([safeLat, safeLng]);
  }, [safeLat, safeLng]);

  return (
    <div style={{ height: 300, width: "100%", borderRadius: 8, overflow: "hidden", border: "1px solid var(--border-subtle)", marginTop: 8 }}>
      <MapContainer center={[safeLat, safeLng]} zoom={12} style={{ height: "100%", width: "100%" }}>
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a>'
          url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
        />
        <LocationMarker position={position} setPosition={setPosition} />
      </MapContainer>
    </div>
  );
}
