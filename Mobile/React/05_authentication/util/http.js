import axios from "axios";

const URL = "https://testing-project-2458c-default-rtdb.firebaseio.com/";

async function fetchMessage(token) {
  try {
    const response = await axios.get(`${URL}/message.json?auth=${token}`);
    return response.data;
  } catch (error) {
    throw new Error("Failed to fetch message");
  }
}

export { fetchMessage };
