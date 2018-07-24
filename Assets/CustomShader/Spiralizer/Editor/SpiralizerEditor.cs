using UnityEngine;
using UnityEditor;
using UnityEditorInternal;

[CustomEditor(typeof(Spiralizer)), CanEditMultipleObjects]
sealed class SpiralizerEditor : Editor
{
    SerializedProperty _density;
    SerializedProperty _size;

    SerializedProperty _inflation;
    SerializedProperty _rotation;
    SerializedProperty _origin;

    SerializedProperty _emissionColor;
    SerializedProperty _edgeColor;
    SerializedProperty _edgeWidth;
    SerializedProperty _hueShift;
    SerializedProperty _highlight;

    ReorderableList _renderers;

    static class Styles
    {
        public static readonly GUIContent BaseEmission = new GUIContent("Base Emission");
    }

    void OnEnable()
    {
        _density = serializedObject.FindProperty("_density");
        _size = serializedObject.FindProperty("_size");

        _inflation = serializedObject.FindProperty("_inflation");
        _rotation = serializedObject.FindProperty("_rotation");
        _origin = serializedObject.FindProperty("_origin");

        _emissionColor = serializedObject.FindProperty("_emissionColor");
        _edgeColor = serializedObject.FindProperty("_edgeColor");
        _edgeWidth = serializedObject.FindProperty("_edgeWidth");
        _hueShift = serializedObject.FindProperty("_hueShift");
        _highlight = serializedObject.FindProperty("_highlight");

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

        EditorGUILayout.LabelField("Basic Settings", EditorStyles.boldLabel);
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_density);
        EditorGUILayout.PropertyField(_size);
        EditorGUI.indentLevel--;

        EditorGUILayout.LabelField("Animation", EditorStyles.boldLabel);
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_inflation);
        EditorGUILayout.PropertyField(_rotation);
        EditorGUILayout.PropertyField(_origin);
        EditorGUI.indentLevel--;

        EditorGUILayout.LabelField("Appearance", EditorStyles.boldLabel);
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_emissionColor, Styles.BaseEmission);
        EditorGUILayout.PropertyField(_edgeColor);
        EditorGUILayout.PropertyField(_edgeWidth);
        EditorGUILayout.PropertyField(_hueShift);
        EditorGUILayout.PropertyField(_highlight);
        EditorGUI.indentLevel--;

        EditorGUILayout.Space();

        _renderers.DoLayoutList();

        EditorGUILayout.Space();

        serializedObject.ApplyModifiedProperties();
    }
}
