import {
  launchCameraAsync,
  launchImageLibraryAsync,
  PermissionStatus,
  useCameraPermissions,
  useMediaLibraryPermissions,
} from "expo-image-picker";
import { Alert, Image, StyleSheet, Text, View } from "react-native";

import { Colors } from "../../constants/styles";
import OutlinedButton from "../UI/OutlinedButton";

function ImagePicker({ pickedImage, onImageTaken }) {
  const [cameraPermissionInformation, requestCameraPermission] =
    useCameraPermissions();
  const [galleryPermissionInformation, requestGalleryPermission] =
    useMediaLibraryPermissions();

  async function verifyPermissions(permissionInformation, requestPermission) {
    if (permissionInformation.status === PermissionStatus.UNDETERMINED) {
      const permissionResponse = await requestPermission();
      return permissionResponse.granted;
    }

    if (permissionInformation.status === PermissionStatus.DENIED) {
      Alert.alert(
        "Insufficient Permissions!",
        "You need to grant permissions to use this app."
      );
      return false;
    }

    return true;
  }

  async function takeImageHandler() {
    const hasPermission = await verifyPermissions(
      cameraPermissionInformation,
      requestCameraPermission
    );
    if (!hasPermission) {
      return;
    }

    const result = await launchCameraAsync({
      allowsEditing: true,
      aspect: [16, 9],
      quality: 0.5,
    });

    if (!result.canceled) {
      onImageTaken(result.assets[0].uri);
    }
  }

  async function pickImageHandler() {
    const hasPermission = await verifyPermissions(
      galleryPermissionInformation,
      requestGalleryPermission
    );
    if (!hasPermission) {
      return;
    }

    const result = await launchImageLibraryAsync({
      allowsEditing: true,
      aspect: [16, 9],
      quality: 0.5,
    });

    if (!result.canceled) {
      onImageTaken(result.assets[0].uri);
    }
  }

  let imagePreview = <Text>No image taken yet.</Text>;

  if (pickedImage) {
    imagePreview = <Image style={styles.image} source={{ uri: pickedImage }} />;
  }

  return (
    <View>
      <View style={styles.imagePreview}>{imagePreview}</View>
      <View style={styles.buttonContainer}>
        <OutlinedButton icon="camera" onPress={takeImageHandler}>
          Take Image
        </OutlinedButton>
        <OutlinedButton icon="image" onPress={pickImageHandler}>
          Pick Image
        </OutlinedButton>
      </View>
    </View>
  );
}

export default ImagePicker;

const styles = StyleSheet.create({
  imagePreview: {
    width: "100%",
    height: 200,
    marginVertical: 8,
    justifyContent: "center",
    alignItems: "center",
    backgroundColor: Colors.primary100,
    borderRadius: 4,
    overflow: "hidden",
  },
  image: {
    width: "100%",
    height: "100%",
    borderRadius: 4,
  },
  buttonContainer: {
    flexDirection: "row",
    justifyContent: "center",
  },
});
