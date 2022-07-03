terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.76.0"
    }
  }
}

# Сеть
resource "yandex_vpc_network" "netology" {
  name = "netology"
}

# Подсеть public
resource "yandex_vpc_subnet" "public" {
  name           = "public"
  zone           = "ru-central1-a"                # выбираем зону а
  network_id     = yandex_vpc_network.netology.id # указываем id созданного vpc
  v4_cidr_blocks = ["192.168.10.0/24"]            # указываем диапазон адресов
}

# Подсеть private
resource "yandex_vpc_subnet" "private" {
  name           = "private"
  zone           = "ru-central1-b"                         # выбираем зону b
  network_id     = yandex_vpc_network.netology.id          # указываем id созданного vpc
  v4_cidr_blocks = ["192.168.20.0/24"]                     # указываем диапазон адресов
  route_table_id = yandex_vpc_route_table.private-route.id # указываем id на таблицу маршрутизации в NAT-instance
}

# Таблица маршрутизации из private подсети в nat-instance public подсети
resource "yandex_vpc_route_table" "private-route" {
  network_id = yandex_vpc_network.netology.id
  name       = "nat-instance-route"

  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat-instance.network_interface.0.ip_address # ссылка на локальный ip адрес созданного NAT-instance
  }
}

# NAT-instance
resource "yandex_compute_instance" "nat-instance" {
  name = "nat-instance"
  zone = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd80mrhj8fl2oe87o4e1"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public.id # размещаем в public подсети
    nat       = true # подключаем внешний ip адрес
  }

}

# public-instance (виртуальная машина на ubuntu)
resource "yandex_compute_instance" "public-instance" {
  name        = "public-instance"
  zone        = "ru-central1-a"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8f30hur3255mjfi3hq"
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.public.id # размещаем в public подсети
    nat       = true                        # подключаем внешний ip адрес
  }

  metadata = {
    user-data = "${file("~/meta.txt")}"
  }
}

# private-instance (виртуальная машина на ubuntu)
resource "yandex_compute_instance" "private-instance" {
  name        = "private-instance"
  zone        = "ru-central1-b"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd8f30hur3255mjfi3hq"
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.private.id # размещаем в private подсети
    nat       = false                        # без внешнего ip адреса
  }

  metadata = {
    user-data = "${file("~/meta.txt")}"
  }
}