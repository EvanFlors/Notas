import { createSlice } from "@reduxjs/toolkit";

const initialState = {
  ids: [],
};

const favoriteMealsSlice = createSlice({
  name: "favoriteMeals",
  initialState,
  reducers: {
    addFavorite: (state, action) => {
      state.ids.push(action.payload.id);
    },
    removeFavorite: (state, action) => {
      state.ids = state.ids.filter((id) => id !== action.payload.id);
    },
  },
});

export const { addFavorite, removeFavorite } = favoriteMealsSlice.actions;

export default favoriteMealsSlice.reducer;
