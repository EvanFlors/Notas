export class Place {
  constructor(title, imageUri, location, id) {
    this.id = id ? id : new Date().toString() + Math.random().toString();
    this.title = title;
    this.imageUri = imageUri;
    this.address = location.address;
    this.location = { lat: location.lat, lng: location.lng }; // { lat: 0, lng: 0}
  }
}
