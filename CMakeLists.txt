cmake_minimum_required(VERSION 3.21)
project(kocaeli-ulasim VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
endif()

include(GNUInstallDirs)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Widgets Network Qml Quick QuickControls2
    Positioning Location DBus Multimedia ShaderTools Test)
find_package(KF6Kirigami REQUIRED)
find_package(KF6StatusNotifierItem REQUIRED)
find_package(KF6DBusAddons REQUIRED)

qt_standard_project_setup(REQUIRES 6.5)

# Mantık (Qt Quick'siz): uygulama ve testler paylaşır.
add_library(transitcore STATIC
    src/KentKart.cpp src/KentKart.h
    src/Text.cpp src/Text.h
    src/TrackingLogic.cpp src/TrackingLogic.h
)
target_include_directories(transitcore PUBLIC src)
target_link_libraries(transitcore PUBLIC Qt6::Core Qt6::Network Qt6::Positioning)

qt_add_executable(kocaeli-ulasim src/main.cpp)
target_compile_definitions(kocaeli-ulasim PRIVATE PROJECT_VERSION="${PROJECT_VERSION}")

set_source_files_properties(qml/ui/Theme.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

qt_add_qml_module(kocaeli-ulasim
    URI KocaeliUlasim
    VERSION 1.0
    SOURCES
        src/Api.cpp src/Api.h
        src/RouteCatalog.cpp src/RouteCatalog.h
        src/Store.cpp src/Store.h
        src/Tracker.cpp src/Tracker.h
        src/Notifier.cpp src/Notifier.h
    QML_FILES
        qml/Main.qml
        qml/HomePage.qml
        qml/StopPage.qml
        qml/RoutePage.qml
        qml/MapPage.qml
        qml/TrackingsPage.qml
        qml/SettingsPage.qml
        qml/TrackSetupDialog.qml
        qml/RouteBadge.qml
        qml/BadgeRow.qml
        qml/TransitMap.qml
        qml/Fmt.js
        qml/LiveSync.js
        qml/SwapText.qml
        qml/ui/Theme.qml
        qml/ui/Txt.qml
        qml/ui/Symbol.qml
        qml/ui/Sym.js
        qml/ui/Section.qml
        qml/ui/ListRow.qml
        qml/ui/PillButton.qml
        qml/ui/LinkButton.qml
        qml/ui/IconButton.qml
        qml/ui/SegmentedControl.qml
        qml/ui/Toggle.qml
        qml/ui/SearchBar.qml
        qml/ui/Spinner.qml
        qml/ui/SkeletonRow.qml
        qml/ui/EmptyState.qml
        qml/ui/Banner.qml
        qml/ui/PageScaffold.qml
        qml/ui/Sidebar.qml
        qml/ui/IconTile.qml
        qml/ui/Stepper.qml
        qml/ui/Sheet.qml
        qml/ui/ActionSheet.qml
        qml/ui/Toast.qml
        qml/ui/ChoiceRow.qml
        qml/ui/Chips.qml
        qml/ui/ScrollIndicator.qml
    RESOURCES
        data/dev.enaimami.KocaeliUlasim.svg
        data/fonts/InterVariable.ttf
        data/fonts/symbols.ttf
)

qt_add_shaders(kocaeli-ulasim "shaders"
    PREFIX "/"
    FILES shaders/darkmap.frag
)

target_link_libraries(kocaeli-ulasim PRIVATE
    transitcore
    Qt6::Gui Qt6::Widgets Qt6::Qml Qt6::Quick Qt6::QuickControls2
    Qt6::Location Qt6::DBus Qt6::Multimedia
    KF6::StatusNotifierItem KF6::DBusAddons
)

install(TARGETS kocaeli-ulasim RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
configure_file(data/dev.enaimami.KocaeliUlasim.desktop.in ${CMAKE_CURRENT_BINARY_DIR}/dev.enaimami.KocaeliUlasim.desktop @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/dev.enaimami.KocaeliUlasim.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES data/dev.enaimami.KocaeliUlasim.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)

enable_testing()
qt_add_executable(tests tests/tst_logic.cpp)
target_link_libraries(tests PRIVATE transitcore Qt6::Test)
target_compile_definitions(tests PRIVATE FIXTURES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests/fixtures")
add_test(NAME tests COMMAND tests)
