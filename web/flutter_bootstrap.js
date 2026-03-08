{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    // Use canvaskit renderer (default in Flutter 3.41)
    renderer: "canvaskit",
  },
  onEntrypointLoaded: async function(engineInitializer) {
    let appRunner = await engineInitializer.initializeEngine({
      // Enable accessibility/semantics by default for better interaction
    });
    await appRunner.runApp();
  }
});
