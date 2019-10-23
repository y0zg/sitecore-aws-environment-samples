job "sitecore" {
  datacenters = ["eu-north-1a", "eu-north-1b", "eu-north-1c"]

  group "example" {
    task "iis" {
      driver = "docker"
  
      config {
        image = "mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2019"
        port_map {
          iis = 80
        }
      }
  
      resources {
        network {
          mbits = 10
          port "http" {
            static = 80
          }
        }
      }

    }
  }
}

