output "user_data_ecs_windows" {
  value = "${data.template_file.user_data_windows.rendered}"
}
