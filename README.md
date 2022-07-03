# Домашнее задание к занятию "15.1. Организация сети"

Домашнее задание будет состоять из обязательной части, которую необходимо выполнить на провайдере Яндекс.Облако и дополнительной части в AWS по желанию. Все домашние задания в 15 блоке связаны друг с другом и в конце представляют пример законченной инфраструктуры.  
Все задания требуется выполнить с помощью Terraform, результатом выполненного домашнего задания будет код в репозитории. 

Перед началом работ следует настроить доступ до облачных ресурсов из Terraform используя материалы прошлых лекций и [ДЗ](https://github.com/netology-code/virt-homeworks/tree/master/07-terraform-02-syntax ). А также заранее выбрать регион (в случае AWS) и зону.

---
## Задание 1. Яндекс.Облако (обязательное к выполнению)

<details>

  <summary>Описание задачи</summary> 

1. Создать VPC.
- Создать пустую VPC. Выбрать зону.
2. Публичная подсеть.
- Создать в vpc subnet с названием public, сетью 192.168.10.0/24.
- Создать в этой подсети NAT-инстанс, присвоив ему адрес 192.168.10.254. В качестве image_id использовать fd80mrhj8fl2oe87o4e1
- Создать в этой публичной подсети виртуалку с публичным IP и подключиться к ней, убедиться что есть доступ к интернету.
3. Приватная подсеть.
- Создать в vpc subnet с названием private, сетью 192.168.20.0/24.
- Создать route table. Добавить статический маршрут, направляющий весь исходящий трафик private сети в NAT-инстанс
- Создать в этой приватной подсети виртуалку с внутренним IP, подключиться к ней через виртуалку, созданную ранее и убедиться что есть доступ к интернету

Resource terraform для ЯО
- [VPC subnet](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_subnet)
- [Route table](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/vpc_route_table)
- [Compute Instance](https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs/resources/compute_instance)

</details>

### Решение

Подготовим окружение для работы с Terraform
```shell
export YC_TOKEN=" ваш токен"
export YC_CLOUD_ID="id вашего облака"
export YC_FOLDER_ID="id вашего каталога"
```

Подготовим main.tf и применяем конфигурацию. После развертывания подключаемся к ВМ private-instance через public-instance. Проверяем доступ к интернету (ping yandex.ru).
Если отключить маршрутизацию на nat инстанс из private подсети (закомментировать строку ниже) доступ в интернет пропадет.
>route_table_id = yandex_vpc_route_table.private-route.id
  


main.tf

```json
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
```


---