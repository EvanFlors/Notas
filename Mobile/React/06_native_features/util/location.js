import { GOOGLE_API_KEY } from "@env";

function getMapPreview(lat, lng) {
  const imagePreviewUrl = `https://maps.googleapis.com/maps/api/staticmap?center=${lat},${lng}&zoom=14&size=400x200&maptype=roadmap&markers=color:red%7Clabel:A%7C${lat},${lng}&key=${GOOGLE_API_KEY}`;
  return imagePreviewUrl;
}

async function getAddress(lat, lng) {
  const response = await fetch(
    `https://maps.googleapis.com/maps/api/geocode/json?latlng=${lat},${lng}&key=${GOOGLE_API_KEY}`
  );

  if (!response.ok) {
    throw new Error("Failed to fetch address!");
  }

  const data = await response.json();

  if (!data.results || data.results.length === 0) {
    throw new Error("No address found for the given coordinates!");
  }

  const address = data.results[0].formatted_address;
  return address;
}

export { getAddress, getMapPreview };
