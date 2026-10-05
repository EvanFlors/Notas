import { useEffect, useLayoutEffect, useState } from "react";
import { Alert } from "react-native";

import MapView, { Marker } from "react-native-maps";
import IconButton from "../components/UI/IconButton";

function Map({ navigation, route }) {
  const initialLocation = route.params?.initialLat
    ? {
        lat: route.params.initialLat,
        lng: route.params.initialLng,
      }
    : null;

  const [selectedLocation, setSelectedLocation] = useState(initialLocation);

  useEffect(() => {
    if (initialLocation) {
      setSelectedLocation(initialLocation);
    }
  }, [initialLocation]);

  const initialRegion = {
    latitude: initialLocation ? initialLocation.lat : 37.78825,
    longitude: initialLocation ? initialLocation.lng : -122.4324,
    latitudeDelta: 0.0922,
    longitudeDelta: 0.0421,
  };

  function selectLocationHandler(event) {
    const lat = event.nativeEvent.coordinate.latitude;
    const lng = event.nativeEvent.coordinate.longitude;

    setSelectedLocation({ lat, lng });
  }

  function savePickedLocationHandler() {
    if (!selectedLocation) {
      Alert.alert(
        "No location picked!",
        "You have to pick a location (by tapping on the map) first!"
      );
      return;
    }

    navigation.navigate("AddPlace", {
      pickedLat: selectedLocation.lat,
      pickedLng: selectedLocation.lng,
    });
  }

  useLayoutEffect(() => {
    if (initialLocation) {
      return;
    }

    navigation.setOptions({
      headerRight: ({ tintColor }) => (
        <IconButton
          icon="save"
          size={24}
          color={tintColor}
          onPress={savePickedLocationHandler}
        />
      ),
    });
  }, [navigation, savePickedLocationHandler, initialLocation]);

  return (
    <MapView
      style={{ flex: 1 }}
      initialRegion={initialRegion}
      onPress={selectLocationHandler}
    >
      {selectedLocation && (
        <Marker
          coordinate={{
            latitude: selectedLocation
              ? selectedLocation.lat
              : initialRegion.latitude,
            longitude: selectedLocation
              ? selectedLocation.lng
              : initialRegion.longitude,
          }}
          title="Picked Location"
        />
      )}
    </MapView>
  );
}

export default Map;
