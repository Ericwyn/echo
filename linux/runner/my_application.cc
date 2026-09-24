#include "my_application.h"

#include <flutter_linux/flutter_linux.h>

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows != nullptr) {
    // Reuse the existing application window when launched a second time.
    // gtk_window_present() also restores a window hidden to the system tray.
    gtk_window_present(GTK_WINDOW(windows->data));
    return;
  }

  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Retain GTK client-side decorations so the compositor can draw the window
  // shadow and resize frame. window_manager hides this header bar before the
  // first Flutter frame; Flutter draws the one visible navigation/title bar.
  GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
  gtk_widget_show(GTK_WIDGET(header_bar));
  gtk_header_bar_set_title(header_bar, "echoes");
  gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  gtk_window_set_title(window, "echoes");

  // Rounded GTK corners expose the opaque Flutter view as dark corner pixels.
  // Keep the visible window rectangular and let the GTK theme own shadow
  // geometry during resize and restore.
  gtk_style_context_add_class(
      gtk_widget_get_style_context(GTK_WIDGET(window)), "echoes-desktop");
  GtkCssProvider* window_css = gtk_css_provider_new();
  gtk_css_provider_load_from_data(
      window_css,
      "window.echoes-desktop, window.echoes-desktop.background {"
      "  border-radius: 0;"
      "}"
      "window.echoes-desktop decoration {"
      "  border-radius: 0;"
      "}",
      -1, nullptr);
  gtk_style_context_add_provider_for_screen(
      gtk_widget_get_screen(GTK_WIDGET(window)), GTK_STYLE_PROVIDER(window_css),
      GTK_STYLE_PROVIDER_PRIORITY_APPLICATION);
  g_object_unref(window_css);

  gtk_window_set_default_size(window, 1280, 720);
  // Keep the Linux product shell above Echo's expanded breakpoint so a user
  // cannot resize the desktop app into the compact/mobile route layout.
  // Keep this in sync with echoDesktopMinimumWindowWidth/Height in Dart.
  GdkGeometry minimum_size = {};
  minimum_size.min_width = 840;
  minimum_size.min_height = 560;
  gtk_window_set_geometry_hints(window, nullptr, &minimum_size,
                                GDK_HINT_MIN_SIZE);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  // Keep the default Flutter renderer for normal runs. This opt-in diagnostic
  // switch lets us compare Impeller and the legacy renderer on the same Linux
  // bundle when investigating compositor flicker during resize or restore.
  if (g_strcmp0(g_getenv("ECHO_DISABLE_IMPELLER"), "1") == 0) {
    fl_dart_project_set_enable_impeller(project, FALSE);
    g_message("Echoes: Impeller disabled for this diagnostic run");
  }
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application shutdown.

  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_FLAGS_NONE, nullptr));
}
