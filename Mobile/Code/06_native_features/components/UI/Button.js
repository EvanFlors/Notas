import { Pressable, StyleSheet, Text, View } from "react-native";

import { Colors } from "../../constants/styles";

function Button({ children, onPress, mode, style }) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => pressed && styles.pressed}
    >
      <View style={[styles.button, mode === "flat" && styles.flat, style]}>
        <Text style={[styles.buttonText, mode === "flat" && styles.flatText]}>
          {children}
        </Text>
      </View>
    </Pressable>
  );
}

export default Button;

const styles = StyleSheet.create({
  button: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    margin: 4,
    backgroundColor: Colors.primary800,
    elevation: 2,
    shadowColor: "black",
    shadowOffset: { width: 1, height: 1 },
    shadowOpacity: 0.35,
    shadowRadius: 4,
    borderRadius: 4,
  },
  flat: {
    backgroundColor: "transparent",
    elevation: 0,
    shadowColor: "transparent",
  },
  flatText: {
    color: Colors.primary200,
  },
  buttonText: {
    color: Colors.primary50,
    textAlign: "center",
    fontSize: 16,
  },
  pressed: {
    opacity: 0.7,
  },
});
