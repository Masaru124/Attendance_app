import cv2
import numpy as np
import base64
import io
from PIL import Image
import json
from typing import List, Optional


def encode_face(base64_image: str) -> Optional[List[float]]:
  
    try:
        print(f"=== BACKEND FACE DETECTION DEBUG ===")
        print(f"Input base64 length: {len(base64_image)}")
        
        # Decode base64 image
        image_data = base64.b64decode(base64_image)
        image = Image.open(io.BytesIO(image_data))
        
        print(f"Original image size: {image.size}")
        print(f"Original image mode: {image.mode}")
        
        image_array = np.array(image)
        print(f"Image array shape: {image_array.shape}")
        
        if len(image_array.shape) == 3 and image_array.shape[2] == 3:
            image_array = cv2.cvtColor(image_array, cv2.COLOR_RGB2BGR)
            print("Converted RGB to BGR")
        
        face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
        
        gray = cv2.cvtColor(image_array, cv2.COLOR_BGR2GRAY)
        
        gray = cv2.equalizeHist(gray)
        print("Applied histogram equalization")
        
        all_faces = []
        
        faces1 = face_cascade.detectMultiScale(gray, 1.1, 6, minSize=(50, 50))
        print(f"Method 1 detected {len(faces1)} faces")
        all_faces.extend(faces1)
        
        # Method 2: Balanced detection
        faces2 = face_cascade.detectMultiScale(gray, 1.05, 5, minSize=(40, 40))
        print(f"Method 2 detected {len(faces2)} faces")
        all_faces.extend(faces2)
        
        faces3 = face_cascade.detectMultiScale(gray, 1.02, 4, minSize=(30, 30))
        print(f"Method 3 detected {len(faces3)} faces")
        all_faces.extend(faces3)
        
        filtered_faces = []
        for face in all_faces:
            is_duplicate = False
            x, y, w, h = face
            for existing in filtered_faces:
                ex, ey, ew, eh = existing
                # Check if faces overlap significantly (>50% area overlap)
                overlap_x = max(0, min(x + w, ex + ew) - max(x, ex))
                overlap_y = max(0, min(y + h, ey + eh) - max(y, ey))
                overlap_area = overlap_x * overlap_y
                face_area = w * h
                existing_area = ew * eh
                if overlap_area > 0.5 * min(face_area, existing_area):
                    is_duplicate = True
                    break
            if not is_duplicate:
                filtered_faces.append(face)
        
        print(f"Filtered to {len(filtered_faces)} unique faces")
        
        # If we have faces, select the best one
        faces = filtered_faces
        
        # Reject if no face detected
        if len(faces) == 0:
            print("No faces detected with improved Haar Cascade")
            return None
            
        # Select the largest face (most likely to be the main subject)
        x, y, w, h = max(faces, key=lambda rect: rect[2] * rect[3])
        print(f"Selected largest face: x={x}, y={y}, w={w}, h={h}")
        
        # Additional quality check: face should be reasonably large and centered
        image_height, image_width = gray.shape
        face_area_ratio = (w * h) / (image_width * image_height)
        center_x, center_y = x + w/2, y + h/2
        image_center_x, image_center_y = image_width/2, image_height/2
        center_distance = ((center_x - image_center_x)**2 + (center_y - image_center_y)**2)**0.5
        max_center_distance = min(image_width, image_height) * 0.3
        
        print(f"Face area ratio: {face_area_ratio:.3f}")
        print(f"Face center distance from image center: {center_distance:.1f}")
        
        # Quality filters
        if face_area_ratio < 0.02:  # Face too small (<2% of image)
            print("Face rejected: too small")
            return None
            
        if center_distance > max_center_distance:  # Face too far from center
            print("Face rejected: too far from center")
            return None
        
        # Extract face region with some padding
        padding = 10
        face_region = image_array[max(0, y-padding):min(y+h+padding, image_array.shape[0]), 
                              max(0, x-padding):min(x+w+padding, image_array.shape[1])]
        
        print(f"Face region shape: {face_region.shape}")
        
        # Resize to standard size for consistent embedding
        face_resized = cv2.resize(face_region, (64, 64))
        print(f"Resized face shape: {face_resized.shape}")
        
        # Generate embedding (flattened pixel values)
        embedding = face_resized.flatten().tolist()
        print(f"Generated embedding with {len(embedding)} dimensions")
        
        print(f"=== END FACE DETECTION DEBUG ===")
        return embedding
        
    except Exception as e:
        print(f"Error encoding face: {str(e)}")
        return None


def verify_face(stored_embedding_str: str, new_embedding: List[float], tolerance: float = 0.6) -> bool:
    """
    Verify if new face embedding matches stored embedding using Euclidean distance.
    This works with the improved OpenCV face detection embeddings.
    
    Args:
        stored_embedding_str: JSON string of stored face embedding
        new_embedding: New face embedding list (4096-dimensional from 64x64 face)
        tolerance: Face recognition tolerance (lower = stricter)
        
    Returns:
        True if faces match, False otherwise
    """
    try:
        print(f"=== FACE VERIFICATION DEBUG ===")
        print(f"Stored embedding length: {len(stored_embedding_str)}")
        print(f"New embedding length: {len(new_embedding)}")
        
        # Parse stored embedding
        stored_embedding = json.loads(stored_embedding_str)
        
        # Convert to numpy arrays
        stored_array = np.array(stored_embedding)
        new_array = np.array(new_embedding)
        
        # Calculate Euclidean distance
        distance = np.linalg.norm(stored_array - new_array)
        
        # Normalize distance to 0-1 range for better comparison
        max_distance = np.linalg.norm(stored_array)
        normalized_distance = distance / max_distance if max_distance > 0 else 0
        
        print(f"Raw distance: {distance:.6f}")
        print(f"Normalized distance: {normalized_distance:.6f}")
        print(f"Tolerance: {tolerance}")
        print(f"Match result: {normalized_distance <= tolerance}")
        
        # Return True if distance is within tolerance
        result = normalized_distance <= tolerance
        
        print(f"=== END FACE VERIFICATION DEBUG ===")
        return result
        
    except Exception as e:
        print(f"Error verifying face: {str(e)}")
        return False


def embedding_to_string(embedding: List[float]) -> str:
    """
    Convert face embedding list to JSON string for storage.
    
    Args:
        embedding: Face embedding list
        
    Returns:
        JSON string representation
    """
    return json.dumps(embedding)


def string_to_embedding(embedding_str: str) -> List[float]:
    """
    Convert JSON string back to face embedding list.
    
    Args:
        embedding_str: JSON string of face embedding
        
    Returns:
        Face embedding list
    """
    try:
        return json.loads(embedding_str)
    except:
        return []
