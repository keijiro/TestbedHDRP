using UnityEngine;
using UnityEditor;
using UnityEditorInternal;

[CustomEditor(typeof(Transporter))]
sealed class TransporterEditor : Editor
{
    SerializedProperty _cellDensity;
    SerializedProperty _cellSize;

    SerializedProperty _origin;
    SerializedProperty _swirl;
    SerializedProperty _scatter;

    SerializedProperty _emissionColor;
    SerializedProperty _edgeColor;
    SerializedProperty _hueShift;

    ReorderableList _renderers;

    static class Styles
    {
        public static readonly GUIContent Density = new GUIContent("Density");
        public static readonly GUIContent Size = new GUIContent("Size");
        public static readonly GUIContent BaseEmission = new GUIContent("Base Emission");
        public static readonly GUIContent Edge = new GUIContent("Edge");
    }

    void OnEnable()
    {
        _cellDensity = serializedObject.FindProperty("_cellDensity");
        _cellSize = serializedObject.FindProperty("_cellSize");

        _origin = serializedObject.FindProperty("_origin");
        _swirl = serializedObject.FindProperty("_swirl");
        _scatter = serializedObject.FindProperty("_scatter");

        _emissionColor = serializedObject.FindProperty("_emissionColor");
        _edgeColor = serializedObject.FindProperty("_edgeColor");
        _hueShift = serializedObject.FindProperty("_hueShift");

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
        EditorGUI.indentLevel--;

        EditorGUILayout.LabelField("Animation Parameters");
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_origin);
        EditorGUILayout.PropertyField(_swirl);
        EditorGUILayout.PropertyField(_scatter);
        EditorGUI.indentLevel--;

        EditorGUILayout.LabelField("Color Attributes");
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_emissionColor, Styles.BaseEmission);
        EditorGUILayout.PropertyField(_edgeColor, Styles.Edge);
        EditorGUILayout.PropertyField(_hueShift);
        EditorGUI.indentLevel--;

        _renderers.DoLayoutList();

        EditorGUILayout.Space();

        serializedObject.ApplyModifiedProperties();
    }
}
