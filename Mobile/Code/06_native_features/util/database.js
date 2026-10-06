import * as SQLite from "expo-sqlite";
import { Place } from "../models/place";

const database = SQLite.openDatabaseSync("places.db");

export async function init() {
  await database.execAsync(
    `CREATE TABLE IF NOT EXISTS places (
      id INTEGER PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      imageUri TEXT NOT NULL,
      address TEXT NOT NULL,
      lat REAL NOT NULL,
      lng REAL NOT NULL
    )`
  );
}

export async function insertPlace(place) {
  return database.runAsync(
    `INSERT INTO places (title, imageUri, address, lat, lng) VALUES (?, ?, ?, ?, ?)`,
    [
      place.title,
      place.imageUri,
      place.address,
      place.location.lat,
      place.location.lng,
    ]
  );
}

export async function fetchPlaces() {
  const rows = await database.getAllAsync(`SELECT * FROM places`);

  return rows.map(
    (dp) =>
      new Place(
        dp.title,
        dp.imageUri,
        {
          address: dp.address,
          lat: dp.lat,
          lng: dp.lng,
        },
        dp.id
      )
  );
}

export async function fetchPlaceDetails(id) {
  const rows = await database.getAllAsync(`SELECT * FROM places WHERE id = ?`, [
    id,
  ]);

  if (rows.length === 0) {
    throw new Error("Place not found");
  }

  const dp = rows[0];

  return new Place(
    dp.title,
    dp.imageUri,
    {
      address: dp.address,
      lat: dp.lat,
      lng: dp.lng,
    },
    dp.id
  );
}
