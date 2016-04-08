using UnityEngine;
using System.Collections;
using UnityEngine.UI;

public class InputManager : MonoBehaviour
{
	// Editor
	#if UNITY_EDITOR
	private float mouseSensitivityX = 2.5f;
	private float mouseSensitivityY = 2.5f;
	// Mobile
	#else
	private GameObject camParent, camYRotator;
	private Gyroscope gyro;
	private float yAngleOffset = 0.0f;
	#endif

	// Component/Variable Cache
	private Transform cameraTransform;
	private float cameraRotationX, cameraRotationY;

	private void Awake()
	{
		// Editor
		#if UNITY_EDITOR
		cameraTransform = Camera.main.transform;
		cameraRotationX = cameraTransform.localEulerAngles.x;
		cameraRotationY = cameraTransform.localEulerAngles.y;

		// Mobile
		#else
		gyro = Input.gyro;
		gyro.enabled = true;

		camParent = new GameObject ("CamParent");
		camParent.transform.position = transform.position;
		transform.parent = camParent.transform;

		// Rotate the parent object by 90 degrees around the x axis
		camParent.transform.Rotate(Vector3.right, 90);

		// Set up the parent object of camParent to handle y rotation.
		camYRotator = new GameObject("CamYRotator");
		camYRotator.transform.position = transform.position;
		camParent.transform.parent = camYRotator.transform;
		#endif
	}

	private void Update ()
	{
		// Editor
		#if UNITY_EDITOR
		cameraRotationX += Input.GetAxis("Mouse Y") * mouseSensitivityY;
		cameraRotationY += Input.GetAxis("Mouse X") * mouseSensitivityX;

		cameraTransform.localEulerAngles = new Vector3(-cameraRotationX, cameraRotationY, 0);

		//Mobile
		#else
		// Invert the z and w of the gyro attitude
		Quaternion rotFix = new Quaternion(gyro.attitude.x, gyro.attitude.y, -gyro.attitude.z, -gyro.attitude.w);

		// Now set the local rotation of the child camera object
		transform.localRotation = rotFix;
		#endif
	}

	public void CenterCamera()
	{
		#if UNITY_EDITOR
		#else
		camYRotator.transform.Rotate(Vector3.up, -yAngleOffset);
		yAngleOffset = -transform.rotation.eulerAngles.y;
		camYRotator.transform.Rotate(Vector3.up, yAngleOffset);
		#endif
	}
}
