import { Platform, Pressable, StyleSheet, Text, View } from "react-native";

function CategoryGridTile(props) {
  return (
    <View style={styles.gridItem}>
      <Pressable
        android_ripple={{ color: "#ccc" }}
        style={({ pressed }) => [
          styles.button,
          pressed ? styles.buttonPressed : null,
        ]}
        onPress={props.onPress}
      >
        <View style={[styles.innerContainer, { backgroundColor: props.color }]}>
          <Text style={styles.title}>{props.title}</Text>
        </View>
      </Pressable>
    </View>
  );
}

export default CategoryGridTile;

const styles = StyleSheet.create({
  gridItem: {
    flex: 1,
    margin: 16,
    height: 150,
    borderRadius: 8,
    elevation: 4, // Android shadow
    shadowColor: "black", // iOS shadow
    shadowOpacity: 0.25, // iOS shadow
    shadowOffset: { width: 0, height: 2 }, // iOS shadow
    shadowRadius: 8, // iOS shadow
    overflow: Platform.OS === "android" ? "hidden" : "visible", // Android clipping for ripple effect
  },
  innerContainer: {
    flex: 1,
    borderRadius: 8,
    padding: 16,
    justifyContent: "center",
    alignItems: "center",
  },
  button: {
    flex: 1,
  },
  buttonPressed: {
    opacity: 0.5, // Visual feedback for press on Android
  },
  title: {
    fontWeight: "bold",
    fontSize: 18,
  },
});
