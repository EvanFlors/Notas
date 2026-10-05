import { Image, Pressable, StyleSheet, Text, View } from "react-native";

import { Colors } from "../../constants/styles";

function PlaceItem({ place, onSelect }) {
  return (
    <Pressable
      style={({ pressed }) => [styles.pressable, pressed && styles.pressed]}
      onPress={onSelect.bind(this, place.id)}
    >
      <Image source={{ uri: place.imageUri }} style={styles.image} />
      <View style={styles.textContainer}>
        <Text style={styles.title}>{place.title}</Text>
        <Text style={styles.address}>{place.address}</Text>
      </View>
    </Pressable>
  );
}

export default PlaceItem;

const styles = StyleSheet.create({
  pressable: {
    backgroundColor: Colors.primary50,
    flexDirection: "row",
    alignItems: "center",
    padding: 10,
    shadowColor: Colors.gray700,
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  image: {
    width: 100,
    height: 100,
    borderRadius: 25,
    marginRight: 30,
    alignSelf: "center",
  },
  textContainer: {
    flex: 1,
  },
  title: {
    fontWeight: "600",
    textAlign: "left",
    fontSize: 18,
    marginBottom: 4,
  },
  address: {
    color: Colors.gray700,
    textAlign: "left",
    fontSize: 14,
  },
  pressed: {
    opacity: 0.75,
  },
});
