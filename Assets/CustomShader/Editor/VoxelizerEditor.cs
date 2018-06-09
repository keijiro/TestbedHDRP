using UnityEngine;
using UnityEditor;
using UnityEditorInternal;

[CustomEditor(typeof(Voxelizer))]
sealed class VoxelizerEditor : Editor
{
    SerializedProperty _density;
    SerializedProperty _scale;

    SerializedProperty _stretch;
    SerializedProperty _fallDistance;
    SerializedProperty _fluctuation;

    ReorderableList _renderers;

    void OnEnable()
    {
        _density = serializedObject.FindProperty("_density");
        _scale = serializedObject.FindProperty("_scale");

        _stretch = serializedObject.FindProperty("_stretch");
        _fallDistance = serializedObject.FindProperty("_fallDistance");
        _fluctuation = serializedObject.FindProperty("_fluctuation");

        _renderers = new ReorderableList(
            serializedObject,
            serializedObject.FindProperty("_renderers"),
            true, // draggable
            true, // displayHeader
            true, // displayAddButton
            true  // displayRemoveButton
        );

        _renderers.drawHeaderCallback = (Rect rect) => {  
            EditorGUI.LabelField(rect, "Target Renderers");
        };

        _renderers.drawElementCallback = (Rect frame, int index, bool isActive, bool isFocused) => {
            var rect = frame;
            rect.y += 2;
            rect.height = EditorGUIUtility.singleLineHeight;
            var element = _renderers.serializedProperty.GetArrayElementAtIndex(index);
            EditorGUI.PropertyField(rect, element, GUIContent.none);
        };
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        EditorGUILayout.LabelField("Voxel Parameters");
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_density);
        EditorGUILayout.PropertyField(_scale);
        EditorGUI.indentLevel--;

        EditorGUILayout.LabelField("Animation Parameters");
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_stretch);
        EditorGUILayout.PropertyField(_fallDistance);
        EditorGUILayout.PropertyField(_fluctuation);
        EditorGUI.indentLevel--;

        _renderers.DoLayoutList();

        EditorGUILayout.Space();

        serializedObject.ApplyModifiedProperties();
    }
}
