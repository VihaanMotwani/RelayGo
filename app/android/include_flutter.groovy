// include_flutter.groovy
// This script includes the Flutter module for add-to-app integration

def flutterProjectRoot = rootProject.projectDir.parentFile

gradle.include ':flutter'
gradle.project(':flutter').projectDir = new File(flutterProjectRoot, '.android/Flutter')

def plugins = new Properties()
def pluginsFile = new File(flutterProjectRoot, '.flutter-plugins')
if (pluginsFile.exists()) {
    pluginsFile.withReader('UTF-8') { reader -> plugins.load(reader) }
}

plugins.each { name, path ->
    def pluginDirectory = new File(path, 'android')
    if (pluginDirectory.exists()) {
        gradle.include ":$name"
        gradle.project(":$name").projectDir = pluginDirectory
    }
}
