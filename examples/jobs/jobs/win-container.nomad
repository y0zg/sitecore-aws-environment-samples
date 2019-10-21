job "sitecore" {
  datacenters = ["aws-prod"]

  group "example" {
    task "iis" {
    driver = "docker"

    config {
      image = "mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2019"
      port_map {
        iis = 80
      }

      args = [
      ]
    }

    resources {
      network {
      mbits = 10
      port "iis" {}
    }
  }
}
}
}

