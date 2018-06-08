using UnityEngine;
using UnityEditor;
using UnityEditorInternal;

[CustomEditor(typeof(Effector))]
sealed class EffectorEditor : Editor
{
    SerializedProperty _extrusion;
    ReorderableList _renderers;

    void OnEnable()
    {
        _extrusion = serializedObject.FindProperty("_extrusion");

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

        EditorGUILayout.PropertyField(_extrusion);
        _renderers.DoLayoutList();
        EditorGUILayout.Space();

        serializedObject.ApplyModifiedProperties();
    }
}
