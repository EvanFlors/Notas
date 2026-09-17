import { FlatList, StyleSheet, View } from "react-native";
import MealItem from "./MealItem";

function MealList({ items }) {
  const renderMealItem = (itemData) => {
    const item = itemData.item;

    const mealItemProps = {
      id: item.id,
      title: item.title,
      imageUrl: item.imageUrl,
      duration: item.duration,
      complexity: item.complexity,
      affordability: item.affordability,
    };

    return <MealItem {...mealItemProps} />;
  };

  return (
    <View style={styles.mealsList}>
      <FlatList
        data={items}
        keyExtractor={(item) => item.id}
        renderItem={renderMealItem}
        style={{ width: "100%" }}
      />
    </View>
  );
}

export default MealList;

const styles = StyleSheet.create({
  mealsList: {
    flex: 1,
    padding: 16,
  },
});
