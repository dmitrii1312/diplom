terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  backend "s3" {
    endpoint = "storage.yandexcloud.net"
    bucket = "diplom"
    region = "ru-central1"
    key = "diplomstate/terrastate"
    access_key = "YCAJElj2DSFz2MUdbefGnYsqq"
    secret_key = "YCMDsWT44G39keFfW-nZ7PcDNWXSeO70E2bGWBzK"
    skip_region_validation = true
    skip_credentials_validation = true
  }
}

