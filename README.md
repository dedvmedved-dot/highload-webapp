
---

# Полное описание проекта: путь от технического задания до реализации

## Содержание

1. [Цель проекта и техническое задание](#1-цель-проекта)
2. [Архитектура решения](#2-архитектура-решения)
3. [Использованные технологии и их роль](#3-использованные-технологии)
4. [Создание инфраструктуры: Terraform](#4-создание-инфраструктуры-terraform)
5. [Настройка серверов: Ansible](#5-настройка-серверов-ansible)
6. [Балансировка и отказоустойчивость: Nginx + Keepalived](#6-балансировка-и-отказоустойчивость)
7. [Backend: Django + uWSGI](#7-backend-django--uwsgi)
8. [База данных: PostgreSQL](#8-база-данных-postgresql)
9. [GFS2: кластерная файловая система](#9-gfs2-кластерная-файловая-система)
10. [Проверка отказоустойчивости](#10-проверка-отказоустойчивости)
11. [Пройденные трудности и их решения](#11-пройденные-трудности)
12. [Реальные применения архитектуры](#12-реальные-применения)

---

## 1. Цель проекта

### Техническое задание

Создать отказоустойчивую инфраструктуру для высоконагруженного веб-приложения со следующими компонентами:

| Компонент | Количество | Технология |
|-----------|-----------|------------|
| Балансировщик | 2 сервера | Nginx + Keepalived (VRRP) |
| Сервер приложений | 2 сервера | Django + uWSGI |
| База данных | 1 сервер | PostgreSQL (некластеризованная) |
| Файловое хранилище | Кластерное | GFS2 через iSCSI |
| Инфраструктура | Код | Terraform + Ansible |

### Ключевое требование

Система должна продолжать работу при отказе **любого одного** сервера уровня frontend (nginx) или backend (Django).

---

## 2. Архитектура решения

### Схема: Архитектура отказоустойчивой системы

```dot
digraph Architecture {
    label="Архитектура отказоустойчивой инфраструктуры";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.8;
    ranksep=0.7;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=11];
    
    user [label="Пользователь\nHTTP-запрос", shape=oval, fillcolor="#E8F0FE", style=filled];
    
    subgraph cluster_layer1 {
        label="Слой 1: Балансировка (Frontend)";
        style=filled;
        fillcolor="#FCE8E6";
        color="#EA4335";
        fontsize=14;
        
        vip [label="Виртуальный IP\n192.168.122.100\n(Keepalived VRRP)", shape=hexagon, fillcolor="#FFF9C4", style=filled];
        
        subgraph cluster_nginx {
            label="Nginx Cluster";
            style=filled;
            fillcolor="#FFCDD2";
            
            nginx1 [label="nginx-1\nMASTER\npriority=100\nNginx + Keepalived\n.122.7", fillcolor="#EF9A9A", style=filled];
            nginx2 [label="nginx-2\nBACKUP\npriority=90\nNginx + Keepalived\n.122.214", fillcolor="#EF9A9A", style=filled];
        }
    }
    
    subgraph cluster_layer2 {
        label="Слой 2: Приложения (Backend)";
        style=filled;
        fillcolor="#FFF3E0";
        color="#FB8C00";
        fontsize=14;
        
        subgraph cluster_backend {
            label="Django + uWSGI Cluster";
            style=filled;
            fillcolor="#FFE0B2";
            
            be1 [label="backend-1\nDjango + uWSGI\n4 workers :8000\n.122.238", fillcolor="#FFCC80", style=filled];
            be2 [label="backend-2\nDjango + uWSGI\n4 workers :8000\n.122.75", fillcolor="#FFCC80", style=filled];
        }
    }
    
    subgraph cluster_layer3 {
        label="Слой 3: Данные (Storage)";
        style=filled;
        fillcolor="#F3E5F5";
        color="#9C27B0";
        fontsize=14;
        
        subgraph cluster_gfs2 {
            label="GFS2 Cluster Storage";
            style=filled;
            fillcolor="#E1BEE7";
            
            iscsi [label="iscsi-target\nБлочное устройство\nLVM + iSCSI\n.122.111", shape=cylinder, fillcolor="#CE93D8", style=filled];
            gfs2_fs [label="GFS2 Filesystem\n/mnt/gfs2_static\nОдновременный доступ\nс двух узлов", shape=cylinder, fillcolor="#CE93D8", style=filled];
        }
        
        pg [label="PostgreSQL 14\nНекластеризованная\nСУБД\ndjango_db\n.122.189", shape=cylinder, fillcolor="#CE93D8", style=filled];
    }
    
    subgraph cluster_mgmt {
        label="Infrastructure as Code";
        style=filled;
        fillcolor="#E0E0E0";
        color="#616161";
        fontsize=14;
        
        tf [label="Terraform\nСоздание ВМ\nmain.tf", fillcolor="#BDBDBD", style=filled];
        ansible [label="Ansible\nНастройка ПО\n4 роли", fillcolor="#BDBDBD", style=filled];
    }
    
    user -> vip [label="HTTP-запрос", penwidth=2, color="#EA4335"];
    vip -> nginx1 [label="VRRP\nMASTER", color="#34A853", penwidth=2];
    vip -> nginx2 [label="VRRP\nBACKUP", style=dashed, color="#34A853"];
    
    nginx1 -> be1 [label="proxy_pass\nround-robin", color="#4285F4"];
    nginx1 -> be2 [label="proxy_pass\nround-robin", color="#4285F4"];
    nginx2 -> be1 [label="proxy_pass", style=dashed, color="#4285F4"];
    nginx2 -> be2 [label="proxy_pass", style=dashed, color="#4285F4"];
    
    be1 -> pg [label="SQL\nORM", color="#9C27B0"];
    be2 -> pg [label="SQL\nORM", color="#9C27B0"];
    
    be1 -> gfs2_fs [label="чтение/\nзапись", dir=both, color="#7B1FA2", penwidth=2];
    be2 -> gfs2_fs [label="чтение/\nзапись", dir=both, color="#7B1FA2", penwidth=2];
    iscsi -> gfs2_fs [label="iSCSI\n/dev/sda", color="#7B1FA2", penwidth=2];
    
    tf -> nginx1 [style=dotted, color="#616161"];
    tf -> be1 [style=dotted, color="#616161"];
    ansible -> nginx1 [style=dashed, color="#616161"];
    ansible -> be1 [style=dashed, color="#616161"];
}
```

### Описание архитектуры

Система построена по трёхслойной архитектуре:

**Слой 1 — Балансировка (Frontend):**
Два сервера nginx образуют отказоустойчивый кластер. Keepalived по протоколу VRRP управляет виртуальным IP-адресом `192.168.122.100`. В нормальном режиме VIP находится на nginx-1 (MASTER, приоритет 100). При отказе MASTER — VIP автоматически перемещается на nginx-2 (BACKUP, приоритет 90).

**Слой 2 — Приложения (Backend):**
Два сервера с Django и uWSGI обрабатывают HTTP-запросы. Nginx распределяет нагрузку между ними по алгоритму round-robin. При отказе одного backend — nginx исключает его из ротации.

**Слой 3 — Данные (Storage):**
- **PostgreSQL** — единая база данных (по условию — некластеризованная)
- **GFS2** — кластерная файловая система для статических файлов. Оба backend-сервера одновременно монтируют одну ФС через iSCSI

---

## 3. Использованные технологии и их роль

### Схема: Технологический стек

```dot
digraph TechStack {
    label="Технологический стек проекта";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.8;
    ranksep=0.6;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=11];
    
    subgraph cluster_iaac {
        label="Infrastructure as Code";
        style=filled;
        fillcolor="#E0E0E0";
        fontsize=14;
        
        git [label="Git\nВерсионирование\nкода инфраструктуры", shape=cylinder, fillcolor="#BDBDBD", style=filled];
        
        tf [label="Terraform 1.12\nHCL-язык\nДекларативное описание\nРесурсы: ВМ, диски, сеть\nПровайдер: libvirt", fillcolor="#BDBDBD", style=filled];
        
        ansible [label="Ansible\nYAML-плейбуки\nРоли: nginx, backend,\ndb, gfs2, iscsi-target\nМодули: apt, systemd,\ntemplate, lineinfile", fillcolor="#BDBDBD", style=filled];
    }
    
    subgraph cluster_virt {
        label="Виртуализация";
        style=filled;
        fillcolor="#E8F0FE";
        fontsize=14;
        
        kvm [label="KVM\nГипервизор ядра Linux\nАппаратная\nвиртуализация", fillcolor="#BBDEFB", style=filled];
        libvirt [label="libvirt\nAPI управления\nvirsh, virt-install\nПул хранения default", fillcolor="#BBDEFB", style=filled];
        qemu [label="QEMU\nЭмуляция устройств\nvirtio-драйверы\nОбразы qcow2", fillcolor="#BBDEFB", style=filled];
    }
    
    subgraph cluster_services {
        label="Сервисы и протоколы";
        style=filled;
        fillcolor="#E6F4EA";
        fontsize=14;
        
        keepalived [label="Keepalived\nVRRP (RFC 5798)\nПлавающий IP\nДетекция отказов\nadvert_int: 1 сек", fillcolor="#A5D6A7", style=filled];
        nginx [label="Nginx\nReverse Proxy\nБалансировка\nround-robin\nСтатика: alias", fillcolor="#A5D6A7", style=filled];
        uwsgi [label="uWSGI\nApplication Server\nWSGI-протокол\n4 worker процесса\nhttp-socket :8000", fillcolor="#A5D6A7", style=filled];
        django [label="Django\nWeb Framework\nORM, URL routing\nГенерация HTML", fillcolor="#A5D6A7", style=filled];
        postgres [label="PostgreSQL 14\nРеляционная СУБД\nACID-транзакции\nlisten_addresses: *", fillcolor="#A5D6A7", style=filled];
        
        subgraph cluster_gfs2_tech {
            label="GFS2 Stack";
            style=filled;
            fillcolor="#C8E6C9";
            
            iscsi_tech [label="iSCSI\nБлочный доступ\nпо сети TCP/3260\nCHAP-аутентификация", fillcolor="#A5D6A7", style=filled];
            lvm [label="LVM\nУправление томами\nvg_iscsi/lv_static\n4 ГБ", fillcolor="#A5D6A7", style=filled];
            dlm [label="DLM\nDistributed Lock\nManager\nКоординация\nблокировок", fillcolor="#A5D6A7", style=filled];
            gfs2_fs [label="GFS2\nКластерная ФС\nlock_dlm\n2 журнала\nОдновременный\nдоступ", fillcolor="#A5D6A7", style=filled];
        }
    }
    
    git -> tf;
    git -> ansible;
    tf -> kvm;
    kvm -> libvirt;
    libvirt -> qemu;
    ansible -> keepalived;
    ansible -> nginx;
    ansible -> uwsgi;
    ansible -> django;
    ansible -> postgres;
    ansible -> iscsi_tech;
    ansible -> lvm;
    ansible -> dlm;
    ansible -> gfs2_fs;
}
```

### Описание технологий

**Terraform** (HashiCorp) — инструмент для декларативного управления инфраструктурой. Мы описали 6 виртуальных машин, их диски, cloud-init настройки в файлах `.tf`. Одна команда `terraform apply` создаёт всю инфраструктуру.

**Ansible** (Red Hat) — система управления конфигурациями. Мы создали 5 ролей, каждая из которых настраивает определённый компонент. Плейбук `deploy.yml` запускает роли в правильном порядке.

**KVM/libvirt** — стек виртуализации Linux. Каждая ВМ — это процесс QEMU, управляемый через libvirt API. Используются образы qcow2 с backing store для экономии места.

**Keepalived** — реализация протокола VRRP. Создаёт виртуальный IP, который перемещается между серверами при отказе. Время обнаружения отказа: 3 × advert_int + skew_time ≈ 3.6 секунды.

**GFS2** — кластерная файловая система от Red Hat. В отличие от NFS, где один сервер владеет диском, в GFS2 все узлы равноправны. DLM координирует блокировки между узлами.

---

## 4. Создание инфраструктуры: Terraform

### Схема: Процесс создания инфраструктуры через Terraform

```dot
digraph TerraformWorkflow {
    label="Процесс работы Terraform";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.6;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    start [label="Начало", shape=oval, fillcolor="#E8F0FE", style=filled];
    
    subgraph cluster_init {
        label="terraform init";
        style=filled;
        fillcolor="#FCE8E6";
        fontsize=13;
        
        read_providers [label="Читает required_providers:\ndmacvicar/libvirt 0.7.1"];
        download [label="Скачивает провайдер\nиз локального кэша\n(~/.terraform.d/plugins)"];
        create_lock [label="Создаёт\n.terraform.lock.hcl"];
    }
    
    subgraph cluster_plan {
        label="terraform plan";
        style=filled;
        fillcolor="#E6F4EA";
        fontsize=13;
        
        read_tf [label="Читает main.tf,\noutputs.tf,\ncloud-init.yaml"];
        calc_diff [label="Вычисляет разницу\nмежду состоянием\n(state) и кодом"];
        show_plan [label="План: 16 ресурсов\n5 ВМ + диски +\ncloud-init ISO"];
    }
    
    subgraph cluster_apply {
        label="terraform apply";
        style=filled;
        fillcolor="#FFF3E0";
        fontsize=13;
        
        steps [label="1. libvirt_volume.ubuntu_image\n   Скачивает образ Ubuntu (~500 МБ)\n\n2. libvirt_volume.disk (×6)\n   Создаёт диски ВМ (10 ГБ каждый)\n\n3. libvirt_cloudinit_disk.init (×6)\n   Создаёт ISO с SSH-ключом\n\n4. libvirt_domain.vm (×6)\n   Запускает виртуальные машины\n\n5. outputs\n   Выводит IP-адреса", fillcolor="#FFE0B2", style=filled];
    }
    
    end [label="6 ВМ запущены\nИнфраструктура готова", shape=oval, fillcolor="#C8E6C9", style=filled];
    
    start -> read_providers;
    read_providers -> download;
    download -> create_lock;
    create_lock -> read_tf;
    read_tf -> calc_diff;
    calc_diff -> show_plan;
    show_plan -> steps;
    steps -> end;
}
```

### Описание процесса

Terraform работает по декларативному принципу: мы описываем **желаемое состояние** инфраструктуры, а Terraform сам определяет, какие действия нужно выполнить.

**Файлы конфигурации:**
- `main.tf` — описание 6 виртуальных машин, их дисков и cloud-init
- `outputs.tf` — вывод IP-адресов и inventory для Ansible
- `cloud-init.yaml` — шаблон для автоматической настройки SSH при первом запуске

**Ключевые ресурсы:**
- `libvirt_volume.ubuntu_image` — базовый образ Ubuntu 22.04 (скачивается один раз)
- `libvirt_volume.disk` — корневые диски ВМ (создаются через backing store — копия образа + diff)
- `libvirt_cloudinit_disk.init` — ISO-образы с настройками cloud-init
- `libvirt_domain.vm` — виртуальные машины (процессы QEMU)

---

## 5. Настройка серверов: Ansible

### Схема: Процесс настройки через Ansible

```dot
digraph AnsibleWorkflow {
    label="Процесс работы Ansible";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.7;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    inventory [label="inventory.ini\n6 серверов\n3 группы:\n[nginx], [backend], [db]", shape=cylinder, fillcolor="#FFF9C4", style=filled];
    
    playbook [label="deploy.yml\n5 ролей:\n1. iscsi-target\n2. gfs2\n3. backend\n4. nginx\n5. db", shape=note, fillcolor="#FFF9C4", style=filled];
    
    subgraph cluster_roles {
        label="Роли Ansible";
        style=filled;
        fillcolor="#E8F0FE";
        fontsize=13;
        
        role1 [label="iscsi-target\n• Установка tgt\n• Создание LVM\n• Настройка target\n• CHAP-аутентификация", fillcolor="#BBDEFB", style=filled];
        role2 [label="gfs2\n• Установка ядра\n• Загрузка модулей DLM, GFS2\n• Подключение iSCSI initiator\n• Создание GFS2 ФС\n• Монтирование", fillcolor="#BBDEFB", style=filled];
        role3 [label="backend\n• Python venv\n• Django проект\n• Конфигурация uWSGI\n• Systemd unit\n• Static root на GFS2", fillcolor="#BBDEFB", style=filled];
        role4 [label="nginx\n• Установка Nginx\n• Конфигурация\n  балансировщика\n• Keepalived MASTER\n• Keepalived BACKUP", fillcolor="#BBDEFB", style=filled];
        role5 [label="db\n• Установка PostgreSQL\n• Создание БД django_db\n• Пользователь django_user\n• listen_addresses = '*'\n• pg_hba.conf", fillcolor="#BBDEFB", style=filled];
    }
    
    result [label="Все серверы\nнастроены", shape=oval, fillcolor="#C8E6C9", style=filled];
    
    inventory -> playbook;
    playbook -> role1;
    role1 -> role2;
    role2 -> role3;
    role3 -> role4;
    role4 -> role5;
    role5 -> result;
}
```

### Описание ролей

**Роль iscsi-target:**
- Устанавливает пакет `tgt` (iSCSI target)
- Создаёт LVM-том `vg_iscsi/lv_static` размером 4 ГБ на диске `/dev/vdb`
- Настраивает target с CHAP-аутентификацией (iscsi-user / iscsi-pass)
- Открывает порт TCP/3260

**Роль gfs2:**
- Устанавливает `linux-image-generic` для поддержки модуля GFS2
- Загружает модули ядра `dlm` и `gfs2`
- Подключается к iSCSI target как инициатор
- Создаёт файловую систему GFS2 с параметрами `lock_dlm`
- Монтирует ФС в `/mnt/gfs2_static`

**Роль backend:**
- Создаёт виртуальное окружение Python с Django и uWSGI
- Инициализирует Django-проект в `/opt/django-app`
- Настраивает `STATIC_ROOT = "/mnt/gfs2_static/static/"`
- Создаёт systemd-юнит для uWSGI с 4 worker-процессами

**Роль nginx:**
- Устанавливает Nginx как reverse proxy
- Настраивает upstream на оба backend-сервера (round-robin)
- Настраивает Keepalived: MASTER на nginx-1, BACKUP на nginx-2
- Статика отдаётся напрямую через `alias /mnt/gfs2_static/static/`

**Роль db:**
- Устанавливает PostgreSQL 14
- Создаёт базу данных `django_db` и пользователя `django_user`
- Настраивает прослушивание на всех интерфейсах
- Разрешает подключения от сети 192.168.122.0/24

---

## 6. Балансировка и отказоустойчивость

### Схема: Работа Keepalived и Nginx

```dot
digraph LoadBalancing {
    label="Механизм балансировки и отказоустойчивости";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.8;
    ranksep=0.6;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    subgraph cluster_vrrp {
        label="VRRP (Keepalived) — Отказоустойчивость IP";
        style=filled;
        fillcolor="#FCE8E6";
        fontsize=13;
        
        master_state [label="nginx-1 (MASTER)\npriority=100\nВладеет VIP 192.168.122.100\nШлёт VRRP Advertisement\nкаждые 1 сек\nна multicast 224.0.0.18", fillcolor="#EF9A9A", style=filled];
        backup_state [label="nginx-2 (BACKUP)\npriority=90\nСлушает VRRP Advertisement\nVIP не назначен\nОжидает отказа MASTER", fillcolor="#FFCDD2", style=filled];
        
        master_state -> backup_state [label="Heartbeat\nкаждые 1 сек", color="#EA4335", penwidth=2];
        
        fail [label="MASTER упал", shape=octagon, fillcolor="#FFEBEE", style=filled];
        fail -> backup_state [label="Нет heartbeat 3+ сек\n→ BACKUP захватывает VIP\n→ Становится MASTER", color="#EA4335", penwidth=2, style=dashed];
    }
    
    subgraph cluster_nginx_lb {
        label="Nginx — Балансировка нагрузки";
        style=filled;
        fillcolor="#E6F4EA";
        fontsize=13;
        
        upstream [label="upstream backend {\n  server 192.168.122.238:8000;\n  server 192.168.122.75:8000;\n}", shape=note, fillcolor="#C8E6C9", style=filled];
        
        req1 [label="Запрос 1 → backend-1", fillcolor="#A5D6A7", style=filled];
        req2 [label="Запрос 2 → backend-2", fillcolor="#A5D6A7", style=filled];
        req3 [label="Запрос 3 → backend-1", fillcolor="#A5D6A7", style=filled];
        req4 [label="Запрос 4 → backend-2", fillcolor="#A5D6A7", style=filled];
        
        upstream -> req1 [label="50%"];
        upstream -> req2 [label="50%"];
        upstream -> req3;
        upstream -> req4;
    }
    
    subgraph cluster_failover {
        label="Отказ backend-1";
        style=filled;
        fillcolor="#FFF3E0";
        fontsize=13;
        
        be1_down [label="backend-1 ✗ УПАЛ", fillcolor="#EF9A9A", style=filled];
        be2_up [label="backend-2 ✓\nПринимает 100%\nнагрузки", fillcolor="#A5D6A7", style=filled, penwidth=2];
        
        be1_down -> be2_up [label="Nginx исключает\nbackend-1 из\nupstream", color="#FB8C00", penwidth=2];
    }
}
```

### Описание механизма

**Keepalived (VRRP):**
1. nginx-1 (MASTER, priority=100) владеет VIP и отправляет VRRP Advertisement каждые 1 сек
2. nginx-2 (BACKUP, priority=90) слушает VRRP Advertisement
3. Если Advertisement не приходит 3+ секунд — BACKUP становится MASTER и назначает VIP себе
4. Когда старый MASTER возвращается — он снова захватывает VIP (preempt mode)

**Формула времени отказа:**
- skew_time = (256 - priority) / 256 = (256 - 90) / 256 = 0.648 секунды
- master_down_interval = 3 × advert_int + skew_time = 3 × 1 + 0.648 = **3.648 секунды**

**Nginx (балансировка):**
- Алгоритм round-robin: запросы распределяются по очереди
- При отказе одного backend — nginx исключает его из ротации
- Статические файлы (`/static/*`) отдаются напрямую, минуя backend

---

## 7. Backend: Django + uWSGI

### Схема: Обработка HTTP-запроса

```dot
digraph RequestProcessing {
    label="Путь HTTP-запроса через систему";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.7;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    http_request [label="HTTP-запрос\nGET / HTTP/1.1\nHost: 192.168.122.100", shape=oval, fillcolor="#E8F0FE", style=filled];
    
    step1 [label="1. Keepalived\nVIP направляет запрос\nна активный nginx\n(MASTER или BACKUP)", fillcolor="#FCE8E6", style=filled];
    
    step2 [label="2. Nginx\nВыбирает backend\nчерез round-robin\nproxy_pass http://backend", fillcolor="#E6F4EA", style=filled];
    
    step3 [label="3. uWSGI\nПринимает HTTP\nПередаёт WSGI-приложению\n4 worker процесса\nобрабатывают параллельно", fillcolor="#FFF3E0", style=filled];
    
    step4 [label="4. Django\nurls.py → View\nORM запрос к PostgreSQL\nРендеринг шаблона\nФормирование HTML", fillcolor="#FFF3E0", style=filled];
    
    step5 [label="5. PostgreSQL\nВыполняет SQL\nВозвращает данные\nчерез psycopg2", fillcolor="#F3E5F5", style=filled];
    
    step6 [label="6. GFS2 (если статика)\nЧтение файла\n/mnt/gfs2_static/static/\nОба backend видят\nодни и те же файлы", fillcolor="#E1BEE7", style=filled];
    
    http_response [label="HTTP-ответ\n200 OK\nContent-Type: text/html\n<html>...</html>", shape=oval, fillcolor="#E8F0FE", style=filled];
    
    http_request -> step1;
    step1 -> step2;
    step2 -> step3;
    step3 -> step4;
    step4 -> step5 [label="если нужны\nданные из БД"];
    step4 -> step6 [label="если запрос\n/static/*"];
    step5 -> step4 [label="данные"];
    step6 -> step4 [label="файл"];
    step4 -> http_response;
}
```

### Описание компонентов

**uWSGI:**
- Application server, реализующий WSGI-протокол
- Запущен с 4 worker-процессами для параллельной обработки
- Слушает HTTP на порту 8000 (`http-socket = 0.0.0.0:8000`)
- Управляется systemd (автозапуск, перезапуск при сбое)

**Django:**
- Web-фреймворк на Python
- ORM для работы с PostgreSQL
- STATIC_ROOT настроен на `/mnt/gfs2_static/static/` (кластерное хранилище)

---

## 8. База данных: PostgreSQL

### Схема: Конфигурация PostgreSQL

```dot
digraph PostgreSQL {
    label="Конфигурация базы данных";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.7;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    pg_server [label="db-1 (192.168.122.189)\nPostgreSQL 14", shape=cylinder, fillcolor="#CE93D8", style=filled];
    
    subgraph cluster_config {
        label="Конфигурация";
        style=filled;
        fillcolor="#F3E5F5";
        fontsize=13;
        
        listen [label="postgresql.conf\nlisten_addresses = '*'\n(слушает все интерфейсы)", fillcolor="#E1BEE7", style=filled];
        hba [label="pg_hba.conf\nhost all django_user\n192.168.122.0/24 md5\n(доступ из сети backend)", fillcolor="#E1BEE7", style=filled];
    }
    
    subgraph cluster_db_objects {
        label="Объекты базы данных";
        style=filled;
        fillcolor="#F3E5F5";
        fontsize=13;
        
        database [label="django_db\nБаза данных Django", shape=cylinder, fillcolor="#E1BEE7", style=filled];
        user [label="django_user\nПользователь БД\nПароль: django_pass\nПрава: ALL", fillcolor="#E1BEE7", style=filled];
    }
    
    subgraph cluster_clients {
        label="Клиенты";
        style=filled;
        fillcolor="#FFF3E0";
        fontsize=13;
        
        be1 [label="backend-1\nDjango ORM\npsycopg2", fillcolor="#FFE0B2", style=filled];
        be2 [label="backend-2\nDjango ORM\npsycopg2", fillcolor="#FFE0B2", style=filled];
    }
    
    be1 -> pg_server [label="SQL-запросы\nпо TCP/5432", color="#9C27B0"];
    be2 -> pg_server [label="SQL-запросы\nпо TCP/5432", color="#9C27B0"];
    pg_server -> listen;
    pg_server -> hba;
    pg_server -> database;
    pg_server -> user;
}
```

### Описание

PostgreSQL — некластеризованная СУБД (по условию задания). Настроена на приём подключений от обоих backend-серверов по сети. В продакшн-решении сюда добавилась бы репликация (Patroni + etcd или streaming replication).

---

## 9. GFS2: кластерная файловая система

### Схема: Архитектура GFS2

```dot
digraph GFS2Detailed {
    label="GFS2 — Кластерная файловая система";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.7;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    subgraph cluster_layer_physical {
        label="Физический уровень";
        style=filled;
        fillcolor="#E8F0FE";
        fontsize=13;
        
        disk [label="Диск /dev/vdb (5 ГБ)\nна iscsi-target", shape=cylinder, fillcolor="#BBDEFB", style=filled];
        lvm [label="LVM\nvg_iscsi\n└─ lv_static (4 ГБ)", fillcolor="#BBDEFB", style=filled];
    }
    
    subgraph cluster_layer_network {
        label="Сетевой уровень (iSCSI)";
        style=filled;
        fillcolor="#E0E0E0";
        fontsize=13;
        
        target [label="iSCSI Target (tgt)\nIQN: iqn.2026-06.local.gfs2:storage\nПорт: TCP/3260\nАутентификация: CHAP\n(iscsi-user / iscsi-pass)", fillcolor="#BDBDBD", style=filled];
        
        subgraph cluster_initiators {
            label="iSCSI Initiators";
            style=filled;
            fillcolor="#EEEEEE";
            
            init1 [label="backend-1\niscsiadm\n/dev/sda", fillcolor="#E0E0E0", style=filled];
            init2 [label="backend-2\niscsiadm\n/dev/sda", fillcolor="#E0E0E0", style=filled];
        }
    }
    
    subgraph cluster_layer_lock {
        label="Уровень блокировок (DLM)";
        style=filled;
        fillcolor="#FFF3E0";
        fontsize=13;
        
        dlm1 [label="dlm_controld\nна backend-1\nУправляет блокировками\nфайлов и ресурсов", fillcolor="#FFE0B2", style=filled];
        dlm2 [label="dlm_controld\nна backend-2\nУправляет блокировками\nфайлов и ресурсов", fillcolor="#FFE0B2", style=filled];
        
        dlm1 -> dlm2 [label="Обмен сообщениями\nо блокировках\nчерез сеть", dir=both, color="#FB8C00", penwidth=2];
    }
    
    subgraph cluster_layer_fs {
        label="Уровень файловой системы (GFS2)";
        style=filled;
        fillcolor="#E6F4EA";
        fontsize=13;
        
        fs_params [label="Параметры GFS2:\n• Lock protocol: lock_dlm\n• Lock table: gfs2-cluster:gfs2\n• 2 журнала\n• Размер блока: 4 КБ\n• UUID: f4cde126...", shape=note, fillcolor="#C8E6C9", style=filled];
        
        mount1 [label="/mnt/gfs2_static\nна backend-1\nmount -t gfs2 -o\nlockproto=lock_dlm\n/dev/sda", fillcolor="#A5D6A7", style=filled];
        mount2 [label="/mnt/gfs2_static\nна backend-2\nmount -t gfs2 -o\nlockproto=lock_dlm\n/dev/sda", fillcolor="#A5D6A7", style=filled];
    }
    
    subgraph cluster_layer_usage {
        label="Использование";
        style=filled;
        fillcolor="#F3E5F5";
        fontsize=13;
        
        static [label="/mnt/gfs2_static/static/\nОбщая папка для\nстатических файлов\nDjango STATIC_ROOT", shape=note, fillcolor="#E1BEE7", style=filled];
        
        write [label="backend-1 пишет\nфайл test.txt", fillcolor="#CE93D8", style=filled];
        read [label="backend-2 читает\nфайл test.txt\nВИДИТ ТО ЖЕ", fillcolor="#CE93D8", style=filled];
    }
    
    disk -> lvm;
    lvm -> target;
    target -> init1 [label="iSCSI LUN"];
    target -> init2 [label="iSCSI LUN"];
    init1 -> dlm1 [label="доступ\nк диску"];
    init2 -> dlm2 [label="доступ\nк диску"];
    dlm1 -> mount1 [label="координация\nблокировок"];
    dlm2 -> mount2 [label="координация\nблокировок"];
    mount1 -> fs_params;
    mount2 -> fs_params;
    mount1 -> static;
    mount2 -> static;
    write -> mount1;
    read -> mount2;
    write -> read [label="один и тот же\nфайл", dir=both, penwidth=2, color="#7B1FA2"];
}
```

### Схема: Сравнение GFS2 с NFS

```dot
digraph GFS2vsNFS {
    label="GFS2 vs NFS: Ключевые отличия";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.8;
    ranksep=0.6;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    subgraph cluster_nfs {
        label="NFS (Network File System)";
        style=filled;
        fillcolor="#FFEBEE";
        color="#EA4335";
        fontsize=13;
        
        nfs_server [label="Сервер NFS\nВладеет диском\nЭкспортирует шару", fillcolor="#EF9A9A", style=filled];
        nfs_client1 [label="Клиент 1\nМонтирует\nудалённую шару", fillcolor="#FFCDD2", style=filled];
        nfs_client2 [label="Клиент 2\nМонтирует\nудалённую шару", fillcolor="#FFCDD2", style=filled];
        
        nfs_server -> nfs_client1 [label="по сети"];
        nfs_server -> nfs_client2 [label="по сети"];
        
        nfs_problem [label="Проблема:\nОтказ сервера NFS\n= потеря доступа\nко всем данным", shape=octagon, fillcolor="#EF9A9A", style=filled];
        nfs_server -> nfs_problem [style=dashed, color="#EA4335"];
    }
    
    subgraph cluster_gfs2 {
        label="GFS2 (Global File System 2)";
        style=filled;
        fillcolor="#E6F4EA";
        color="#34A853";
        fontsize=13;
        
        storage [label="Общее блочное\nустройство\n(iSCSI / SAN)", shape=cylinder, fillcolor="#A5D6A7", style=filled];
        gfs2_node1 [label="Узел 1\nПрямой доступ\nк диску\nGFS2 + DLM", fillcolor="#A5D6A7", style=filled];
        gfs2_node2 [label="Узел 2\nПрямой доступ\nк диску\nGFS2 + DLM", fillcolor="#A5D6A7", style=filled];
        
        storage -> gfs2_node1 [label="iSCSI", color="#34A853"];
        storage -> gfs2_node2 [label="iSCSI", color="#34A853"];
        gfs2_node1 -> gfs2_node2 [label="DLM координирует\nблокировки", dir=both, color="#34A853"];
        
        gfs2_advantage [label="Преимущество:\nВсе узлы равноправны\nОтказ одного узла\nне влияет на остальных", shape=note, fillcolor="#C8E6C9", style=filled];
        gfs2_node1 -> gfs2_advantage;
        gfs2_node2 -> gfs2_advantage;
    }
}
```

### Схема: Процесс монтирования GFS2 на двух узлах

```dot
digraph GFS2Mount {
    label="Процесс инициализации GFS2";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.6;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    start [label="Старт", shape=oval, fillcolor="#E8F0FE", style=filled];
    
    step1 [label="1. Установка linux-image-generic\nОблачное ядро не включает\nмодуль gfs2", fillcolor="#FCE8E6", style=filled];
    step2 [label="2. Перезагрузка с новым ядром\nuname -r: 5.15.0-181-generic", fillcolor="#FCE8E6", style=filled];
    step3 [label="3. Загрузка модулей\nmodprobe dlm\nmodprobe gfs2", fillcolor="#FCE8E6", style=filled];
    step4 [label="4. Запуск DLM\nsystemctl start dlm\ndlm_controld 4.1.1", fillcolor="#FFF3E0", style=filled];
    step5 [label="5. Подключение iSCSI\niscsiadm --login\nПоявляется /dev/sda", fillcolor="#FFF3E0", style=filled];
    step6 [label="6. Создание ФС (один раз)\nmkfs.gfs2 -p lock_dlm\n-t gfs2-cluster:gfs2\n-j 2 /dev/sda", fillcolor="#E6F4EA", style=filled];
    step7 [label="7. Монтирование на ОБОИХ узлах\nmount -t gfs2 -o lockproto=lock_dlm\n/dev/sda /mnt/gfs2_static", fillcolor="#E6F4EA", style=filled];
    step8 [label="8. Готово! Оба узла\nвидят одну ФС\nЗапись на одном узле\nвидна на другом", shape=oval, fillcolor="#C8E6C9", style=filled];
    
    start -> step1;
    step1 -> step2;
    step2 -> step3;
    step3 -> step4;
    step4 -> step5;
    step5 -> step6;
    step6 -> step7;
    step7 -> step8;
}
```

### Подробное описание GFS2

**Что такое GFS2?**
GFS2 (Global File System 2) — кластерная файловая система, разработанная Red Hat. В отличие от традиционных файловых систем (ext4, XFS) и сетевых (NFS, Samba), GFS2 позволяет **нескольким серверам одновременно читать и писать на одно блочное устройство**.

**Как это работает?**

1. **Общее блочное устройство** — в нашем случае это iSCSI LUN, экспортируемый сервером iscsi-target. Оба backend-сервера подключаются к нему как iSCSI-инициаторы.

2. **DLM (Distributed Lock Manager)** — ключевой компонент. Когда backend-1 хочет записать файл, DLM блокирует соответствующие блоки на диске, чтобы backend-2 не мог их изменить одновременно. Блокировки координируются через сеть между демонами `dlm_controld`.

3. **Журналирование** — GFS2 использует 2 журнала (по одному на каждый узел). Это позволяет восстанавливать файловую систему при отказе любого узла.

4. **Lock table** — `gfs2-cluster:gfs2` — уникальное имя, которое идентифицирует кластер. Все узлы, монтирующие ФС, должны использовать одно и то же имя.

**Отличия от NFS:**

| Характеристика | NFS | GFS2 |
|----------------|-----|------|
| Владелец диска | Один сервер | Все узлы равноправны |
| Доступ к данным | По сети через NFS-сервер | Прямой доступ к блочному устройству |
| Отказ сервера | Данные недоступны | Остальные узлы продолжают работу |
| Блокировки | NFS lockd | DLM (распределённый) |
| Производительность | Зависит от сети и сервера | Максимальная (прямой доступ) |

**Проблемы, с которыми мы столкнулись:**

1. **Отсутствие модуля gfs2** — облачное ядро Ubuntu не включает модуль GFS2. Решение: установка `linux-image-generic`.
2. **DLM не запускается в Pacemaker** — ошибка "not configured". Решение: запуск DLM напрямую через systemd.
3. **Разные имена устройств** — на backend-1 `/dev/sda`, на backend-2 `/dev/sdb`. Решение: использование `/dev/disk/by-path/`.
4. **Segmentation fault при размонтировании** — происходит при отсутствии DLM. Решение: всегда запускать DLM перед монтированием.

---

## 10. Проверка отказоустойчивости

### Схема: Тестирование отказоустойчивости

```dot
digraph FailoverTesting {
    label="Методика тестирования отказоустойчивости";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.8;
    ranksep=0.6;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    all_ok [label="СОСТОЯНИЕ: ВСЁ РАБОТАЕТ\nnginx-1: MASTER (VIP)\nnginx-2: BACKUP\nbackend-1: Активен\nbackend-2: Активен\ndb-1: Активен\ncurl http://VIP → Django OK", shape=oval, fillcolor="#C8E6C9", style=filled];
    
    test1 [label="ТЕСТ 1: Отказ nginx-1\nvirsh destroy nginx-1\nОжидание: 3.6 сек\nРезультат: VIP на nginx-2\ncurl http://VIP → Django OK", fillcolor="#E6F4EA", style=filled];
    
    test2 [label="ТЕСТ 2: Отказ backend-1\nvirsh destroy backend-1\nОжидание: мгновенно\nРезультат: nginx исключает\nbackend-1 из upstream\ncurl http://VIP → Django OK", fillcolor="#E6F4EA", style=filled];
    
    test3 [label="ТЕСТ 3: Восстановление\nvirsh start nginx-1\nvirsh start backend-1\nРезультат:\nVIP возвращается на nginx-1\nbackend-1 снова в upstream", fillcolor="#FFF3E0", style=filled];
    
    all_ok -> test1 [label="Шаг 1"];
    test1 -> test2 [label="Шаг 2"];
    test2 -> test3 [label="Шаг 3"];
    test3 -> all_ok [label="Цикл\nзамкнулся"];
    
    result [label="ВЫВОД:\nСистема выдерживает отказ\nлюбого сервера nginx или backend\nЕдинственная точка отказа — БД\n(по условию задания)", shape=oval, fillcolor="#E8F0FE", style=filled, penwidth=2];
    
    test2 -> result;
    test1 -> result;
}
```

### Результаты тестирования

| Тест | Действие | Ожидание | Результат |
|------|----------|----------|-----------|
| 1 | Выключен nginx-1 | VIP переезжает на nginx-2 | ✅ Успешно |
| 2 | Запрос через VIP после отказа nginx-1 | Django отвечает | ✅ Успешно |
| 3 | Выключен backend-1 | Запросы идут через backend-2 | ✅ Успешно |
| 4 | Запрос через VIP после отказа backend-1 | Django отвечает | ✅ Успешно |
| 5 | Восстановление всех серверов | Система возвращается в норму | ✅ Успешно |

---

## 11. Пройденные трудности и их решения

### Схема: Путь через трудности

```dot
digraph Challenges {
    label="Пройденные трудности и их решения";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.7;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    start [label="Начало проекта", shape=oval, fillcolor="#E8F0FE", style=filled];
    
    problem1 [label="Проблема 1: WSL2\nDHCP не работает\nСеть нестабильна\nAppArmor блокирует QEMU\n5 часов попыток", fillcolor="#FFCDD2", style=filled];
    solution1 [label="Решение 1:\nПереход на чистую\nUbuntu 24.04\nРодной KVM", fillcolor="#C8E6C9", style=filled];
    
    problem2 [label="Проблема 2: Terraform init\nregistry.terraform.io\nнедоступен\n(сетевые ограничения)", fillcolor="#FFCDD2", style=filled];
    solution2 [label="Решение 2:\nСкачивание провайдеров\nвручную и установка\nв ~/.terraform.d/plugins", fillcolor="#C8E6C9", style=filled];
    
    problem3 [label="Проблема 3: Доступ к libvirt\nPermission denied\nна /var/run/libvirt/libvirt-sock\nПользователь в группе,\nно права не применились", fillcolor="#FFCDD2", style=filled];
    solution3 [label="Решение 3:\nchmod 666 на сокет\nперезапуск libvirtd\nперезагрузка системы", fillcolor="#C8E6C9", style=filled];
    
    problem4 [label="Проблема 4: AppArmor\nБлокирует QEMU доступ\nк /var/lib/libvirt/images\nОшибка: Permission denied", fillcolor="#FFCDD2", style=filled];
    solution4 [label="Решение 4:\nsystemctl mask apparmor\nsecurity_driver = none\nchown libvirt-qemu:kvm", fillcolor="#C8E6C9", style=filled];
    
    problem5 [label="Проблема 5: uWSGI + Nginx\n502 Bad Gateway\nuwsgi использует свой протокол\nа не HTTP", fillcolor="#FFCDD2", style=filled];
    solution5 [label="Решение 5:\nsocket = :8000\nзаменён на\nhttp-socket = :8000", fillcolor="#C8E6C9", style=filled];
    
    problem6 [label="Проблема 6: GFS2\n• Нет модуля в облачном ядре\n• DLM не запускается\n• mkfs.gfs2 зависает\n• Разные имена устройств\n• Segmentation fault", fillcolor="#FFCDD2", style=filled];
    solution6 [label="Решение 6:\n• linux-image-generic\n• systemctl start dlm\n• Запуск DLM перед mkfs\n• /dev/disk/by-path/\n• Перезагрузка и пересоздание", fillcolor="#C8E6C9", style=filled];
    
    success [label="Проект завершён\nВсе требования выполнены\n12 скриншотов готовы", shape=oval, fillcolor="#A5D6A7", style=filled, penwidth=2];
    
    start -> problem1;
    problem1 -> solution1;
    solution1 -> problem2;
    problem2 -> solution2;
    solution2 -> problem3;
    problem3 -> solution3;
    solution3 -> problem4;
    problem4 -> solution4;
    solution4 -> problem5;
    problem5 -> solution5;
    solution5 -> problem6;
    problem6 -> solution6;
    solution6 -> success;
}
```

### Хронология проблем

| № | Часы | Проблема | Симптомы | Решение |
|---|------|----------|----------|---------|
| 1 | 0-5 | WSL2 + KVM | DHCP не работает, сеть недоступна | Переход на Ubuntu 24.04 |
| 2 | 5-6 | Terraform init | Реестр недоступен | Локальная установка провайдеров |
| 3 | 6-7 | Permission denied | Доступ к libvirt-sock | chmod + перезагрузка |
| 4 | 7-8 | AppArmor | QEMU не читает образы | Отключение AppArmor |
| 5 | 8-9 | 502 Bad Gateway | uwsgi протокол | http-socket |
| 6 | 9-12 | GFS2 | Модули, DLM, имена устройств | Комплексное решение |

---

## 12. Реальные применения архитектуры

```dot
digraph RealWorld {
    label="Где применяются такие системы";
    labelloc=t;
    fontsize=18;
    fontname="Arial";
    rankdir=TB;
    splines=ortho;
    nodesep=0.8;
    ranksep=0.6;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=11];
    
    title [label="Типовые сценарии использования\nотказоустойчивых инфраструктур", shape=plaintext, fontsize=16];
    
    ecommerce [label="E-commerce\nWildberries, Ozon, Amazon\nПиковые нагрузки\nв Чёрную пятницу\nНельзя терять заказы", fillcolor="#FCE8E6", style=filled];
    
    banks [label="Банки\nСбер, Тинькофф, Revolut\nОбработка транзакций\n99.99% доступность\nРегуляторные требования", fillcolor="#FCE8E6", style=filled];
    
    gov [label="Госуслуги\nПортал Госуслуг\nМиллионы пользователей\nПики при подаче\nзаявлений", fillcolor="#FCE8E6", style=filled];
    
    saas [label="SaaS-платформы\nSalesforce, Slack, Notion\nКруглосуточная работа\nГлобальные пользователи\nSLA 99.9%+", fillcolor="#FCE8E6", style=filled];
    
    hosting [label="Хостинг-провайдеры\nSelectel, DataLine, AWS\nТысячи клиентских сайтов\nОбщее хранилище\n(GFS2/OCFS2)", fillcolor="#FCE8E6", style=filled];
    
    media [label="Медиа и соцсети\nInstagram, Pinterest, TikTok\nМиллиарды запросов\nГоризонтальное\nмасштабирование", fillcolor="#FCE8E6", style=filled];
    
    title -> ecommerce;
    title -> banks;
    title -> gov;
    title -> saas;
    title -> hosting;
    title -> media;
}
```

**Ключевые отличия продакшн-решения от учебного:**
- **Репликация БД** — Patroni + etcd для PostgreSQL
- **Мониторинг** — Prometheus + Grafana + Alertmanager
- **Логирование** — ELK Stack (Elasticsearch, Logstash, Kibana)
- **CI/CD** — Jenkins/GitLab CI для автоматического деплоя
- **SSL/TLS** — Let's Encrypt или коммерческие сертификаты
- **WAF** — Web Application Firewall (ModSecurity)
- **CDN** — Cloudflare/CloudFront для статики

---

**Проект выполнен полностью. Все требования задания соблюдены.**

