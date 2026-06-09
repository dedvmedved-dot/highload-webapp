```bash
cd ~/highload-webapp

cat >> README.md << 'EOF'

---

## Полное описание проекта: путь от идеи до реализации

### 1. Что мы построили и зачем?

Мы создали **отказоустойчивую инфраструктуру для высоконагруженного веб-приложения**, которая продолжает работать при выходе из строя любого сервера уровня frontend (nginx) или backend (Django).

**Бизнес-контекст:** Представьте интернет-магазин во время Чёрной пятницы. Отказ одного сервера не должен оставить клиентов без заказов. Наша архитектура решает именно эту задачу.

```dot
digraph BusinessValue {
    rankdir=TB;
    splines=ortho;
    nodesep=0.8;
    ranksep=0.6;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=11];
    
    problem [label="Проблема:\nОдиночный сервер\n= точка отказа", shape=octagon, fillcolor="#FFEBEE", style=filled];
    
    subgraph cluster_solution {
        label="Наше решение";
        style=filled;
        fillcolor="#E6F4EA";
        color="#34A853";
        fontsize=13;
        
        ha [label="High Availability\nОтказоустойчивость", fillcolor="#A5D6A7", style=filled];
        lb [label="Load Balancing\nБалансировка нагрузки", fillcolor="#A5D6A7", style=filled];
        scale [label="Horizontal Scaling\nГоризонтальное\nмасштабирование", fillcolor="#A5D6A7", style=filled];
    }
    
    result [label="Результат:\nДоступность 99.9%+\nНет единой точки отказа", shape=oval, fillcolor="#E8F0FE", style=filled];
    
    problem -> ha [label="требует", penwidth=2];
    problem -> lb [label="требует"];
    problem -> scale [label="требует"];
    ha -> result;
    lb -> result;
    scale -> result;
}
```

---

### 2. Архитектура системы (детальная)

```dot
digraph FullArchitecture {
    rankdir=TB;
    splines=ortho;
    nodesep=0.7;
    ranksep=0.6;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    // Layer 0: User
    user [label="Пользователь\nHTTP-запрос", shape=oval, fillcolor="#E8F0FE", style=filled];
    
    // Layer 1: VIP
    vip [label="Virtual IP (VRRP)\n192.168.122.100\nKeepalived управляет\nперемещением между\nnginx-1 и nginx-2", shape=hexagon, fillcolor="#FFF9C4", style=filled];
    
    // Layer 2: Nginx cluster
    subgraph cluster_nginx {
        label="Слой 1: Балансировщики нагрузки";
        style=filled;
        fillcolor="#FCE8E6";
        color="#EA4335";
        fontsize=13;
        
        nginx1 [label="nginx-1 (MASTER)\nNginx + Keepalived\npriority=100\n.122.7", fillcolor="#FFCDD2", style=filled];
        nginx2 [label="nginx-2 (BACKUP)\nNginx + Keepalived\npriority=90\n.122.214", fillcolor="#FFCDD2", style=filled];
        
        nginx1 -> nginx2 [label="VRRP heartbeat\n(каждые 1 сек)", dir=both, color="#EA4335"];
    }
    
    // Layer 3: Backend cluster
    subgraph cluster_backend {
        label="Слой 2: Серверы приложений";
        style=filled;
        fillcolor="#FFF3E0";
        color="#FB8C00";
        fontsize=13;
        
        be1 [label="backend-1\nDjango + uWSGI\n4 workers :8000\n.122.238", fillcolor="#FFE0B2", style=filled];
        be2 [label="backend-2\nDjango + uWSGI\n4 workers :8000\n.122.75", fillcolor="#FFE0B2", style=filled];
    }
    
    // Layer 4: Storage
    subgraph cluster_storage {
        label="Слой 3: Хранилище данных";
        style=filled;
        fillcolor="#F3E5F5";
        color="#9C27B0";
        fontsize=13;
        
        subgraph cluster_gfs2 {
            label="GFS2 Cluster";
            style=filled;
            fillcolor="#E1BEE7";
            color="#7B1FA2";
            
            iscsi_target [label="iscsi-target\nПредоставляет\nблочное устройство\nчерез iSCSI\n.122.111", fillcolor="#CE93D8", style=filled];
            
            subgraph cluster_gfs2_mount {
                label="Одновременное монтирование";
                style=filled;
                fillcolor="#F3E5F5";
                
                gfs2_mount [label="/dev/sda (4 ГБ)\nGFS2 Filesystem\nLock protocol: lock_dlm\n2 журнала\n/mnt/gfs2_static", shape=cylinder, fillcolor="#E1BEE7", style=filled];
            }
        }
        
        pg [label="PostgreSQL 14\nНекластеризованная\nСУБД\ndjango_db\n.122.189", shape=cylinder, fillcolor="#CE93D8", style=filled];
    }
    
    // Layer 5: Management
    subgraph cluster_mgmt {
        label="Управление инфраструктурой";
        style=filled;
        fillcolor="#E0E0E0";
        color="#616161";
        fontsize=13;
        
        tf [label="Terraform\nСоздание ВМ\nmain.tf", fillcolor="#BDBDBD", style=filled];
        ans [label="Ansible\nНастройка ПО\n4 роли", fillcolor="#BDBDBD", style=filled];
    }
    
    // Connections
    user -> vip [label="HTTP", penwidth=2];
    vip -> nginx1 [label="proxy_pass", penwidth=2];
    vip -> nginx2 [label="если MASTER упал", style=dashed];
    
    nginx1 -> be1 [label="round-robin"];
    nginx1 -> be2 [label="round-robin"];
    nginx2 -> be1 [label="round-robin"];
    nginx2 -> be2 [label="round-robin"];
    
    be1 -> pg [label="SQL"];
    be2 -> pg [label="SQL"];
    
    be1 -> gfs2_mount [label="чтение/запись", dir=both, color="#7B1FA2"];
    be2 -> gfs2_mount [label="чтение/запись", dir=both, color="#7B1FA2"];
    
    iscsi_target -> gfs2_mount [label="iSCSI LUN", color="#7B1FA2", penwidth=2];
    
    tf -> nginx1 [style=dotted, color="#616161"];
    tf -> be1 [style=dotted, color="#616161"];
    ans -> nginx1 [style=dashed, color="#616161"];
    ans -> be1 [style=dashed, color="#616161"];
}
```

---

### 3. GFS2 — Кластерная файловая система (подробный разбор)

**GFS2 (Global File System 2)** — это кластерная файловая система, разработанная Red Hat. Она позволяет нескольким серверам одновременно читать и писать на одно блочное устройство. В отличие от NFS (где один сервер владеет диском, а остальные обращаются к нему по сети), в GFS2 все узлы равноправны и работают напрямую с блочным устройством.

#### 3.1. Компоненты кластера GFS2

```dot
digraph GFS2Components {
    rankdir=TB;
    splines=ortho;
    nodesep=0.8;
    ranksep=0.6;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=11];
    
    subgraph cluster_overview {
        label="Кластер GFS2: три уровня";
        style=filled;
        fillcolor="#F3E5F5";
        color="#9C27B0";
        fontsize=14;
        
        subgraph cluster_level1 {
            label="Уровень 1: Блочное устройство (iSCSI)";
            style=filled;
            fillcolor="#E8F0FE";
            color="#4285F4";
            fontsize=12;
            
            iscsi [label="iscsi-target (192.168.122.111)\n┌─────────────────────────┐\n│ LVM: vg_iscsi/lv_static │\n│ tgt: iSCSI Target        │\n│ LUN 1: 4 ГБ              │\n│ CHAP: iscsi-user/iscsi-pass │\n└─────────────────────────┘", shape=box, fillcolor="#BBDEFB", style=filled];
        }
        
        subgraph cluster_level2 {
            label="Уровень 2: Distributed Lock Manager (DLM)";
            style=filled;
            fillcolor="#FFF3E0";
            color="#FB8C00";
            fontsize=12;
            
            dlm [label="DLM (Distributed Lock Manager)\n┌──────────────────────────────────┐\n│ Координирует блокировки между   │\n│ узлами кластера                  │\n│ Предотвращает конфликты записи   │\n│ Работает поверх TCP/IP           │\n│ dlm_controld на каждом узле      │\n└──────────────────────────────────┘", shape=box, fillcolor="#FFE0B2", style=filled];
        }
        
        subgraph cluster_level3 {
            label="Уровень 3: Файловая система GFS2";
            style=filled;
            fillcolor="#E6F4EA";
            color="#34A853";
            fontsize=12;
            
            gfs2 [label="GFS2 Filesystem\n┌──────────────────────────────────┐\n│ Тип: gfs2                        │\n│ Lock protocol: lock_dlm           │\n│ Lock table: gfs2-cluster:gfs2     │\n│ 2 журнала (по одному на узел)    │\n│ Размер блока: 4 КБ               │\n│ Точка монтирования:               │\n│   /mnt/gfs2_static                │\n└──────────────────────────────────┘", shape=box, fillcolor="#A5D6A7", style=filled];
        }
    }
    
    // Связи между уровнями
    iscsi -> dlm [label="Предоставляет\nблочное устройство\n/dev/sda (по iSCSI)", penwidth=2, color="#4285F4"];
    dlm -> gfs2 [label="Управляет\nблокировками\nпри записи", penwidth=2, color="#FB8C00"];
    gfs2 -> iscsi [label="Читает/пишет\nнапрямую", style=dashed, dir=both, color="#34A853"];
}
```

#### 3.2. Процесс создания и монтирования GFS2

```dot
digraph GFS2Creation {
    rankdir=TB;
    splines=ortho;
    nodesep=0.6;
    ranksep=0.4;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    step1 [label="Шаг 1: Установка ПО\napt install gfs2-utils\napt install dlm-controld", fillcolor="#E8F0FE", style=filled];
    step2 [label="Шаг 2: Загрузка модулей\nmodprobe dlm\nmodprobe gfs2", fillcolor="#E8F0FE", style=filled];
    step3 [label="Шаг 3: Подключение iSCSI\niscsiadm --login\nudevadm trigger\nДиск появляется как /dev/sda", fillcolor="#E8F0FE", style=filled];
    step4 [label="Шаг 4: Запуск DLM\nsystemctl start dlm\ndlm_controld запущен", fillcolor="#FFF3E0", style=filled];
    step5 [label="Шаг 5: Создание ФС\nmkfs.gfs2 -p lock_dlm\n-t gfs2-cluster:gfs2\n-j 2 /dev/sda", fillcolor="#FFF3E0", style=filled];
    step6 [label="Шаг 6: Монтирование\nmount -t gfs2\n-o lockproto=lock_dlm\n/dev/sda /mnt/gfs2_static", fillcolor="#E6F4EA", style=filled];
    step7 [label="Шаг 7: Проверка\nЗапись на backend-1\nЧтение на backend-2\nДанные доступны мгновенно", fillcolor="#E6F4EA", style=filled];
    
    step1 -> step2;
    step2 -> step3;
    step3 -> step4;
    step4 -> step5;
    step5 -> step6;
    step6 -> step7;
}
```

#### 3.3. Как GFS2 обеспечивает одновременный доступ

```dot
digraph GFS2Locking {
    rankdir=LR;
    splines=ortho;
    nodesep=0.6;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    subgraph cluster_be1 {
        label="backend-1";
        style=filled;
        fillcolor="#E8F0FE";
        
        app1 [label="Приложение\n(Django)", shape=oval];
        gfs2_1 [label="GFS2\nмодуль ядра", fillcolor="#BBDEFB", style=filled];
        dlm_1 [label="DLM\ndlm_controld", fillcolor="#BBDEFB", style=filled];
    }
    
    subgraph cluster_be2 {
        label="backend-2";
        style=filled;
        fillcolor="#FFF3E0";
        
        app2 [label="Приложение\n(Django)", shape=oval];
        gfs2_2 [label="GFS2\nмодуль ядра", fillcolor="#FFE0B2", style=filled];
        dlm_2 [label="DLM\ndlm_controld", fillcolor="#FFE0B2", style=filled];
    }
    
    disk [label="/dev/sda\n(4 ГБ GFS2)", shape=cylinder, fillcolor="#E1BEE7", style=filled];
    
    subgraph cluster_scenario {
        label="Сценарий одновременной записи";
        style=filled;
        fillcolor="#E6F4EA";
        color="#34A853";
        
        scenario [label="backend-1 хочет писать в файл X\n→ GFS2 запрашивает эксклюзивную блокировку у DLM\n→ DLM проверяет, не заблокирован ли файл X\n→ Блокировка получена → запись разрешена\n\nbackend-2 хочет читать файл X\n→ GFS2 запрашивает разделяемую блокировку у DLM\n→ DLM проверяет: файл X заблокирован на запись\n→ backend-2 ЖДЁТ освобождения блокировки\n→ backend-1 завершает запись → DLM снимает блокировку\n→ backend-2 получает разделяемую блокировку → чтение разрешено", shape=note, fillcolor="#C8E6C9", style=filled];
    }
    
    app1 -> gfs2_1 [label="write()"];
    app2 -> gfs2_2 [label="read()"];
    gfs2_1 -> dlm_1 [label="запрос\nблокировки"];
    gfs2_2 -> dlm_2 [label="запрос\nблокировки"];
    dlm_1 -> dlm_2 [label="координация", dir=both, penwidth=2, color="#FB8C00"];
    gfs2_1 -> disk [label="прямой\nдоступ"];
    gfs2_2 -> disk [label="прямой\nдоступ"];
}
```

#### 3.4. Сравнение GFS2 с другими решениями

```dot
digraph FSComparison {
    rankdir=TB;
    splines=ortho;
    nodesep=0.6;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    nfs [label="NFS\n┌─────────────────┐\n│ Один сервер      │\n│ владеет диском   │\n│ Остальные —      │\n│ клиенты по сети  │\n│ Точка отказа:    │\n│ NFS-сервер       │\n└─────────────────┘", fillcolor="#FFEBEE", style=filled];
    
    gfs2 [label="GFS2 (наш выбор)\n┌─────────────────┐\n│ Все узлы         │\n│ равноправны      │\n│ Прямой доступ    │\n│ к блочному       │\n│ устройству       │\n│ DLM координирует │\n│ блокировки       │\n└─────────────────┘", fillcolor="#E6F4EA", style=filled];
    
    ocfs2 [label="OCFS2\n┌─────────────────┐\n│ Аналог GFS2      │\n│ от Oracle        │\n│ Не требует DLM   │\n│ Встроен в ядро   │\n│ Ubuntu по умолч. │\n└─────────────────┘", fillcolor="#FFF9C4", style=filled];
    
    ceph [label="CephFS\n┌─────────────────┐\n│ Распределённая   │\n│ файловая система │\n│ Поверх объектного│\n│ хранилища (RADOS)│\n│ Требует минимум  │\n│ 3 узла           │\n└─────────────────┘", fillcolor="#E8F0FE", style=filled];
    
    nfs -> gfs2 [label="Преимущества GFS2:\n- Нет единой точки отказа\n- Выше производительность\n(прямой доступ к диску)", color="#34A853"];
    gfs2 -> ocfs2 [label="Отличие:\nGFS2 требует DLM\nOCFS2 имеет\nвстроенный lock-менеджер", color="#FB8C00"];
    gfs2 -> ceph [label="Отличие:\nCephFS масштабируется\nна десятки узлов\nGFS2 — на 2-16 узлов", color="#4285F4"];
}
```

---

### 4. Как работает Keepalived (VRRP)

**VRRP (Virtual Router Redundancy Protocol)** — стандартный протокол (RFC 5798) для создания отказоустойчивого шлюза. В нашем случае он обеспечивает "плавающий" IP-адрес для балансировщиков.

```dot
digraph VRRPDetail {
    rankdir=TB;
    splines=ortho;
    nodesep=0.8;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    subgraph cluster_normal {
        label="НОРМАЛЬНЫЙ РЕЖИМ";
        style=filled;
        fillcolor="#E6F4EA";
        color="#34A853";
        fontsize=13;
        
        m1 [label="nginx-1 (MASTER)\npriority=100\nВладеет VIP 192.168.122.100\nШлёт VRRP Advertisement\nкаждые 1 сек на 224.0.0.18", fillcolor="#A5D6A7", style=filled];
        b1 [label="nginx-2 (BACKUP)\npriority=90\nСлушает VRRP Advertisement\nVIP не назначен\nОжидает", fillcolor="#C8E6C9", style=filled];
        
        m1 -> b1 [label="VRRP Advertisement\n(multicast)", penwidth=2, color="#34A853"];
    }
    
    subgraph cluster_fail {
        label="РЕЖИМ ОТКАЗА";
        style=filled;
        fillcolor="#FFEBEE";
        color="#EA4335";
        fontsize=13;
        
        m2 [label="nginx-1 ✗ УПАЛ\nНе шлёт VRRP Advertisement", fillcolor="#EF9A9A", style=filled];
        b2 [label="nginx-2 → СТАЛ MASTER\nНе получает heartbeat 3 сек\nЗахватывает VIP 192.168.122.100\nНачинает обрабатывать запросы", fillcolor="#A5D6A7", style=filled];
        
        m2 -> b2 [label="Нет heartbeat\nskew_time = (256-90)/256 = 0.64 сек\nmaster_down_interval = 3×1 + 0.64 = 3.64 сек", style=dashed, color="#EA4335", penwidth=2];
    }
    
    subgraph cluster_restore {
        label="ВОССТАНОВЛЕНИЕ";
        style=filled;
        fillcolor="#FFF3E0";
        color="#FB8C00";
        fontsize=13;
        
        m3 [label="nginx-1 ВОССТАНОВЛЕН\npriority=100 > 90\nСнова шлёт VRRP Advertisement\nЗахватывает VIP обратно", fillcolor="#A5D6A7", style=filled];
        b3 [label="nginx-2 → BACKUP\nОтдаёт VIP\nВозвращается в режим ожидания", fillcolor="#C8E6C9", style=filled];
        
        m3 -> b3 [label="preempt mode\n(возврат VIP)", penwidth=2, color="#FB8C00"];
    }
}
```

**Формула времени отказа:**
- `skew_time = (256 - priority) / 256` = (256-90)/256 = 0.64 сек
- `master_down_interval = 3 × advert_int + skew_time` = 3×1 + 0.64 = **3.64 секунды**
- Именно столько проходит с момента отказа nginx-1 до захвата VIP нодой nginx-2

---

### 5. Поток обработки HTTP-запроса

```dot
digraph RequestFlow {
    rankdir=TB;
    splines=ortho;
    nodesep=0.7;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    edge [fontname="Arial", fontsize=9];
    
    start [label="HTTP-запрос\nGET http://192.168.122.100/", shape=oval, fillcolor="#E8F0FE", style=filled];
    
    step1 [label="ШАГ 1: Keepalived\nVIP 192.168.122.100\nнаправляет запрос\nна активный nginx\n(MASTER или BACKUP)", fillcolor="#FCE8E6", style=filled];
    
    step2 [label="ШАГ 2: Nginx\nАлгоритм round-robin\nВыбирает backend:\nbackend-1:8000 или\nbackend-2:8000\nproxy_pass http://backend", fillcolor="#E6F4EA", style=filled];
    
    step3 [label="ШАГ 3: uWSGI\nПринимает HTTP-запрос\nПередаёт Django WSGI\n4 worker процесса\nобрабатывают конкурентно", fillcolor="#FFF3E0", style=filled];
    
    step4 [label="ШАГ 4: Django\nURL routing → View\nORM запрос к PostgreSQL\nГенерация HTML-ответа\nСтатика: чтение из\n/mnt/gfs2_static/static/", fillcolor="#FFF3E0", style=filled];
    
    step5 [label="ШАГ 5: PostgreSQL\nВыполняет SQL-запрос\nВозвращает данные\nСлушает на всех\nинтерфейсах (0.0.0.0)", fillcolor="#F3E5F5", style=filled];
    
    step6 [label="ШАГ 6: GFS2 (для статики)\nЕсли запрос /static/*\nЧитает файл с общего\nGFS2-раздела\nОба backend видят\nодни и те же файлы", fillcolor="#E1BEE7", style=filled];
    
    end [label="HTTP-ответ\nHTML страница\nили статический файл", shape=oval, fillcolor="#E8F0FE", style=filled];
    
    start -> step1;
    step1 -> step2;
    step2 -> step3;
    step3 -> step4;
    step4 -> step5 [label="если нужны данные"];
    step4 -> step6 [label="если статика"];
    step5 -> step4 [label="данные"];
    step6 -> step4 [label="файл"];
    step4 -> end;
}
```

---

### 6. Инструменты и их роль

```dot
digraph ToolsAndRoles {
    rankdir=TB;
    splines=ortho;
    nodesep=0.8;
    ranksep=0.6;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    subgraph cluster_iaac {
        label="Infrastructure as Code";
        style=filled;
        fillcolor="#E0E0E0";
        fontsize=13;
        
        git [label="Git\nВерсионирование кода\nинфраструктуры", shape=cylinder, fillcolor="#BDBDBD", style=filled];
        
        tf [label="Terraform\nДекларативное описание\nинфраструктуры\n(HCL — HashiCorp Language)\nСоздаёт: ВМ, диски, сеть", fillcolor="#BDBDBD", style=filled];
        
        ansible [label="Ansible\nКонфигурационный\nменеджмент\n(YAML-плейбуки)\nУстанавливает: nginx,\nDjango, PostgreSQL, GFS2", fillcolor="#BDBDBD", style=filled];
    }
    
    subgraph cluster_virt {
        label="Виртуализация";
        style=filled;
        fillcolor="#E8F0FE";
        fontsize=13;
        
        kvm [label="KVM (Kernel Virtual\nMachine)\nГипервизор 1-го типа\nВстроен в ядро Linux", fillcolor="#BBDEFB", style=filled];
        libvirt [label="libvirt\nAPI для управления\nKVM/QEMU\nvirsh, virt-install", fillcolor="#BBDEFB", style=filled];
        qemu [label="QEMU\nЭмуляция устройств\nПроцесс qemu-system-x86_64\nдля каждой ВМ", fillcolor="#BBDEFB", style=filled];
    }
    
    subgraph cluster_services {
        label="Сервисы и протоколы";
        style=filled;
        fillcolor="#E6F4EA";
        fontsize=13;
        
        vrrp [label="VRRP (Keepalived)\nПлавающий IP\nДетекция отказов\nRFC 5798", fillcolor="#A5D6A7", style=filled];
        nginx_svc [label="Nginx\nReverse Proxy\nRound-robin\nБалансировка", fillcolor="#A5D6A7", style=filled];
        uwsgi_svc [label="uWSGI\nApplication Server\nWSGI-протокол\n4 worker процесса", fillcolor="#A5D6A7", style=filled];
        django_svc [label="Django\nPython Web Framework\nORM, URL routing\nГенерация ответов", fillcolor="#A5D6A7", style=filled];
        pg_svc [label="PostgreSQL 14\nРеляционная СУБД\nACID-транзакции\nSQL", fillcolor="#A5D6A7", style=filled];
        iscsi_proto [label="iSCSI\nБлочный доступ\nпо сети\nTCP/3260", fillcolor="#A5D6A7", style=filled];
        gfs2_fs [label="GFS2\nКластерная ФС\nОдновременный доступ\nlock_dlm", fillcolor="#A5D6A7", style=filled];
    }
    
    git -> tf [label="хранит"];
    git -> ansible [label="хранит"];
    
    tf -> kvm [label="создаёт ВМ"];
    kvm -> libvirt [label="управляет"];
    libvirt -> qemu [label="запускает"];
    
    ansible -> nginx_svc [label="устанавливает"];
    ansible -> uwsgi_svc [label="настраивает"];
    ansible -> django_svc [label="разворачивает"];
    ansible -> pg_svc [label="конфигурирует"];
    ansible -> iscsi_proto [label="настраивает"];
    ansible -> gfs2_fs [label="создаёт"];
    ansible -> vrrp [label="конфигурирует"];
}
```

---

### 7. Пройденные трудности и их решения

```dot
digraph Challenges {
    rankdir=TB;
    splines=ortho;
    nodesep=0.6;
    ranksep=0.5;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=10];
    
    start [label="Начало проекта\n(WSL2 + KVM)", shape=oval, fillcolor="#E8F0FE", style=filled];
    
    subgraph cluster_wsl {
        label="Проблема 1: WSL2 нестабилен";
        style=filled;
        fillcolor="#FFEBEE";
        color="#EA4335";
        fontsize=12;
        
        wsl_problem [label="• DHCP не работает\n• AppArmor блокирует QEMU\n• Сеть нестабильна\n• 5+ часов потеряно", fillcolor="#EF9A9A", style=filled];
        wsl_solution [label="Решение:\nПереход на чистую\nUbuntu 24.04\nРодной KVM\nВсё заработало", fillcolor="#A5D6A7", style=filled];
    }
    
    subgraph cluster_network {
        label="Проблема 2: Сеть в KVM";
        style=filled;
        fillcolor="#FFEBEE";
        color="#EA4335";
        fontsize=12;
        
        net_problem [label="• DHCP выдаёт случайные IP\n• Не совпадают с hostsfile\n• ВМ недоступны по SSH", fillcolor="#EF9A9A", style=filled];
        net_solution [label="Решение:\n• Получать IP через\n  virsh net-dhcp-leases\n• Обновлять inventory\n• Не фиксировать IP в коде", fillcolor="#A5D6A7", style=filled];
    }
    
    subgraph cluster_permissions {
        label="Проблема 3: Права доступа";
        style=filled;
        fillcolor="#FFEBEE";
        color="#EA4335";
        fontsize=12;
        
        perm_problem [label="• Permission denied на образы\n• QEMU не может читать диски\n• libvirt-sock недоступен\n• AppArmor блокирует", fillcolor="#EF9A9A", style=filled];
        perm_solution [label="Решение:\n• chown libvirt-qemu:kvm\n• chmod 775 на все образы\n• Отключить AppArmor\n• Добавить пользователя\n  в группы libvirt, kvm", fillcolor="#A5D6A7", style=filled];
    }
    
    subgraph cluster_gfs2_issues {
        label="Проблема 4: GFS2 — самая сложная часть";
        style=filled;
        fillcolor="#FFEBEE";
        color="#EA4335";
        fontsize=12;
        
        gfs2_problems [label="• Нет модуля gfs2 в облачном ядре\n• DLM не запускается в Pacemaker\n• mkfs.gfs2 зависает без DLM\n• iSCSI диск /dev/sda vs /dev/sdb\n• GFS2 монтируется без кластеризации\n• Segmentation fault при umount\n• Файлы не видны между узлами", fillcolor="#EF9A9A", style=filled];
        gfs2_solutions [label="Решение:\n• Установить linux-image-generic\n• Запустить DLM через systemd\n  (не через Pacemaker)\n• Использовать /dev/disk/by-path/\n• Монтировать с lockproto=lock_dlm\n• Пересоздать ФС после загрузки DLM\n• Перезагрузить узлы для очистки", fillcolor="#A5D6A7", style=filled];
    }
    
    subgraph cluster_uwsgi {
        label="Проблема 5: uWSGI";
        style=filled;
        fillcolor="#FFEBEE";
        color="#EA4335";
        fontsize=12;
        
        uwsgi_problem [label="• uWSGI запущен, порт слушает\n• curl возвращает пустой ответ\n• Nginx: 502 Bad Gateway", fillcolor="#EF9A9A", style=filled];
        uwsgi_solution [label="Решение:\n• uwsgi.ini: socket → http-socket\n• uwsgi-протокол ≠ HTTP\n• После замены — заработало", fillcolor="#A5D6A7", style=filled];
    }
    
    success [label="Проект завершён\nВсе требования выполнены\nОтказоустойчивость подтверждена\nGFS2 кластер работает", shape=oval, fillcolor="#C8E6C9", style=filled];
    
    start -> wsl_problem;
    wsl_problem -> wsl_solution;
    wsl_solution -> net_problem;
    net_problem -> net_solution;
    net_solution -> perm_problem;
    perm_problem -> perm_solution;
    perm_solution -> gfs2_problems;
    gfs2_problems -> gfs2_solutions;
    gfs2_solutions -> uwsgi_problem;
    uwsgi_problem -> uwsgi_solution;
    uwsgi_solution -> success;
}
```

---

### 8. Где применяются такие системы в реальном мире?

| Компания/Сервис | Похожая архитектура | Комментарий |
|-----------------|--------------------|-------------|
| **Netflix** | Nginx + Microservices + EBS | Много backend-сервисов, балансировка через Zuul |
| **Instagram** | Nginx + Django + PostgreSQL | Именно Django! Масштабирование через горизонтальные реплики |
| **Wildberries/Ozon** | Keepalived + Nginx + Backend + PostgreSQL | Высоконагруженный e-commerce в РФ |
| **Госуслуги** | Nginx + Keepalived + PostgreSQL | Отказоустойчивость критична для госсервисов |
| **Банки (Сбер, Тинькофф)** | HA-кластеры + GFS2/Veritas | Кластерные ФС для СУБД и логов |
| **Хостинг-провайдеры** | iSCSI + GFS2 + веб-серверы | Общее хранилище для сотен клиентских сайтов |
| **OpenStack** | Pacemaker + Corosync + GFS2 | Кластерное хранилище для образов ВМ |
| **Red Hat Cluster Suite** | GFS2 + DLM + Pacemaker | Эталонная реализация кластерной ФС |

**Ключевые отличия продакшн-решения от нашего учебного:**
- Добавляется **репликация PostgreSQL** (Patroni + etcd)
- Файловая система выносится на отдельный **SAN-массив**
- Балансировщики объединяются в **AnyCast** (несколько дата-центров)
- Добавляется **мониторинг** (Prometheus + Grafana)
- Настраивается **автоматическое масштабирование** при росте нагрузки
- GFS2 использует **Pacemaker** для автоматического управления ресурсами

---

### 9. Итоговая схема отказоустойчивости (конечный автомат)

```dot
digraph StateMachine {
    rankdir=LR;
    splines=ortho;
    nodesep=0.8;
    ranksep=0.6;
    
    node [shape=box, style=rounded, fontname="Arial", fontsize=11];
    
    all_ok [label="ВСЕ СЕРВЕРЫ РАБОТАЮТ\nnginx-1: MASTER (VIP)\nnginx-2: BACKUP\nbackend-1: Активен\nbackend-2: Активен\ndb-1: Активен", fillcolor="#A5D6A7", style=filled];
    
    nginx_fail [label="ОТКАЗ NGINX-1\nnginx-2 → MASTER\nVIP переехал\nСистема работает", fillcolor="#FFE0B2", style=filled];
    
    backend_fail [label="ОТКАЗ BACKEND-1\nnginx направляет\nзапросы на backend-2\nСистема работает", fillcolor="#FFE0B2", style=filled];
    
    db_fail [label="ОТКАЗ БД\ndb-1 не отвечает\nСистема НЕ работает\n(одиночная БД)", fillcolor="#EF9A9A", style=filled];
    
    all_ok -> nginx_fail [label="virsh destroy nginx-1"];
    nginx_fail -> all_ok [label="virsh start nginx-1\n(preempt возвращает VIP)"];
    
    all_ok -> backend_fail [label="virsh destroy backend-1"];
    backend_fail -> all_ok [label="virsh start backend-1"];
    
    all_ok -> db_fail [label="Отказ db-1", color="#EA4335"];
    db_fail -> all_ok [label="Восстановление db-1", color="#EA4335"];
    
    { rank=same; nginx_fail; backend_fail; }
}
```

**Вывод:** Система выдерживает отказ любого сервера уровня nginx или backend. Единственная единая точка отказа — база данных (по условию задания — некластеризованная СУБД). В продакшн-решении PostgreSQL реплицируется через Patroni или streaming replication.

---

### 10. Чек-лист выполнения всех требований задания

| № | Требование | Статус | Реализация |
|---|-----------|--------|------------|
| 1 | Создать инстансы через Terraform | ✅ | 6 ВМ: 2 nginx, 2 backend, 1 db, 1 iscsi-target |
| 2 | Nginx + Keepalived через Ansible | ✅ | Роль roles/nginx, VRRP VIP 192.168.122.100 |
| 3 | Backend Django + uWSGI через Ansible | ✅ | Роль roles/backend, 4 workers на порту 8000 |
| 4 | **GFS2 для хранения статики** | ✅ | Кластер GFS2 через iSCSI + DLM |
| 5 | PostgreSQL через Ansible | ✅ | Роль roles/db, версия 14, django_db |
| 6 | Keepalived | ✅ | VRRP, MASTER priority=100, BACKUP priority=90 |
| 7 | Nginx/Angie | ✅ | Nginx, балансировка round-robin |
| 8 | uWSGI/Unicorn/PHP-FPM | ✅ | uWSGI с http-socket |
| 9 | Некластеризованная СУБД | ✅ | PostgreSQL на одном узле db-1 |
| 10 | Проверка отказоустойчивости | ✅ | Отказ nginx-1: VIP переезжает, система работает |
| 11 | Проверка отказоустойчивости backend | ✅ | Отказ backend-1: запросы идут на backend-2 |
EOF

echo "README.md обновлён!"
```

```bash
cd ~/highload-webapp
git add README.md
git commit -m "docs: comprehensive project description with all diagrams"
```
