import { StyleSheet, View } from "react-native";
import Colors from "../../constants/colors";

function Card({ children }) {
  return <View style={styles.card}>{children}</View>;
}

export default Card;

const styles = StyleSheet.create({
  card: {
    justifyContent: "center",
    alignItems: "center",
    marginTop: 36,
    marginHorizontal: 24,
    padding: 16,
    backgroundColor: Colors.primary800,
    borderRadius: 8,
    elevation: 4, // for Android shadow
    shadowColor: "black", // for iOS shadow
    shadowOffset: { width: 0, height: 2 }, // for iOS shadow
    shadowRadius: 6, // for iOS shadow
    shadowOpacity: 0.25, // for iOS shadow
  },
});
