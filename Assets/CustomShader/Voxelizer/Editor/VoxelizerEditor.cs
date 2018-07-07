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

    SerializedProperty _emissionColor1;
    SerializedProperty _emissionColor2;
    SerializedProperty _transitionColor;
    SerializedProperty _lineColor;

    ReorderableList _renderers;

    static class Styles
    {
        public static readonly GUIContent Emission1 = new GUIContent("Emission 1");
        public static readonly GUIContent Emission2 = new GUIContent("Emission 2");
        public static readonly GUIContent Transition = new GUIContent("Transition");
        public static readonly GUIContent Line = new GUIContent("Line");
    }

    void OnEnable()
    {
        _density = serializedObject.FindProperty("_density");
        _scale = serializedObject.FindProperty("_scale");

        _stretch = serializedObject.FindProperty("_stretch");
        _fallDistance = serializedObject.FindProperty("_fallDistance");
        _fluctuation = serializedObject.FindProperty("_fluctuation");

        _emissionColor1 = serializedObject.FindProperty("_emissionColor1");
        _emissionColor2 = serializedObject.FindProperty("_emissionColor2");
        _transitionColor = serializedObject.FindProperty("_transitionColor");
        _lineColor = serializedObject.FindProperty("_lineColor");

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

        EditorGUILayout.LabelField("Effect Colors");
        EditorGUI.indentLevel++;
        EditorGUILayout.PropertyField(_emissionColor1, Styles.Emission1);
        EditorGUILayout.PropertyField(_emissionColor2, Styles.Emission2);
        EditorGUILayout.PropertyField(_transitionColor, Styles.Transition);
        EditorGUILayout.PropertyField(_lineColor, Styles.Line);
        EditorGUI.indentLevel--;

        _renderers.DoLayoutList();

        EditorGUILayout.Space();

        serializedObject.ApplyModifiedProperties();
    }
}
