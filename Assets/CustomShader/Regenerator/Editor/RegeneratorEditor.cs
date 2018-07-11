// Regenerator effect custom shader
// https://github.com/keijiro/TestbedHDRP

using UnityEngine;
using UnityEditor;
using UnityEditorInternal;

[CustomEditor(typeof(Regenerator)), CanEditMultipleObjects]
sealed class RegeneratorEditor : Editor
{
    SerializedProperty _cellDensity;
    SerializedProperty _cellSize;
    SerializedProperty _cellDirection;

    SerializedProperty _inflation;
    SerializedProperty _stretch;

    SerializedProperty _emissionColor;
    SerializedProperty _edgeColor;
    SerializedProperty _edgeWidth;
    SerializedProperty _hueShift;
    SerializedProperty _highlight;

    ReorderableList _renderers;

    static class Styles
    {
        public static readonly GUIContent Density = new GUIContent("Density");
        public static readonly GUIContent Size = new GUIContent("Size");
        public static readonly GUIContent Direction = new GUIContent("Direction");
        public static readonly GUIContent BaseEmission = new GUIContent("Base Emission");
        public static readonly GUIContent Width = new GUIContent("Width");
    }

    void OnEnable()
    {
        _cellDensity = serializedObject.FindProperty("_cellDensity");
        _cellSize = serializedObject.FindProperty("_cellSize");
        _cellDirection = serializedObject.FindProperty("_cellDirection");

        _inflation = serializedObject.FindProperty("_inflation");
        _stretch = serializedObject.FindProperty("_stretch");

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

        EditorGUILayout.LabelField("Cell Parameters");
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_cellDensity, Styles.Density);
        EditorGUILayout.PropertyField(_cellSize, Styles.Size);
        EditorGUILayout.PropertyField(_cellDirection, Styles.Direction);
        EditorGUI.indentLevel--;

        EditorGUILayout.LabelField("Animation");
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_inflation);
        EditorGUILayout.PropertyField(_stretch);
        EditorGUI.indentLevel--;

        EditorGUILayout.LabelField("Rendering");
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_emissionColor, Styles.BaseEmission);
        EditorGUILayout.PropertyField(_edgeColor);
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_edgeWidth, Styles.Width);
        EditorGUI.indentLevel--;
        EditorGUILayout.PropertyField(_hueShift);
        EditorGUILayout.PropertyField(_highlight);
        EditorGUI.indentLevel--;

        _renderers.DoLayoutList();

        EditorGUILayout.Space();

        serializedObject.ApplyModifiedProperties();
    }
}
