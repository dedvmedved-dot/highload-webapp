# Highload Web Application — Отказоустойчивая инфраструктура

## Архитектура

┌──────────────────────────┐
│ Keepalived VIP │
│ 192.168.122.100 │
└──────────┬───────────────┘
│
┌───────────────┴───────────────┐
│ │
┌───────┴───────┐ ┌───────┴───────┐
│ nginx-1 │ │ nginx-2 │
│ MASTER │ VRRP │ BACKUP │
│ .122.249 │◄─────────────►│ .122.70 │
└───────┬───────┘ └───────┬───────┘
│ │
└───────────┬───────────────────┘
│
┌───────────┴───────────┐
│ │
┌───────┴───────┐ ┌───────┴───────┐
│ backend-1 │ │ backend-2 │
│ Django+uWSGI │ │ Django+uWSGI │
│ +NFS Server │ │ +NFS Client │
│ .122.62 │ │ .122.14 │
└───────┬───────┘ └───────┬───────┘
│ │
└───────────┬───────────┘
│
┌───────┴───────┐
│ db-1 │
│ PostgreSQL │
│ .122.51 │
└───────────────┘
text


## Компоненты

| Компонент | Технология | Серверы |
|-----------|-----------|---------|
| Балансировка | Nginx | nginx-1, nginx-2 |
| Отказоустойчивость | Keepalived (VRRP) | nginx-1, nginx-2 |
| VIP-адрес | 192.168.122.100 | плавающий |
| Бэкенд | Django + uWSGI | backend-1, backend-2 |
| Статика | NFS | backend-1 (сервер), backend-2 (клиент) |
| База данных | PostgreSQL 14 | db-1 |

## Запуск инфраструктуры

### Требования
- Ubuntu 24.04
- KVM/libvirt
- Terraform 1.12.2
- Ansible

### 1. Создание ВМ (Terraform)
```bash
cd terraform
terraform init
terraform apply -auto-approve

2. Настройка серверов (Ansible)
bash

cd ansible
ansible-playbook -i inventory.ini playbooks/deploy.yml

3. Проверка
bash

curl http://192.168.122.100/

Тестирование отказоустойчивости
Шаг	Действие	Ожидаемый результат	Статус
1	Выключить backend-1	Система работает через backend-2	✅
2	Выключить nginx-1 (MASTER)	VIP переезжает на nginx-2	✅
3	Включить всё обратно	Система восстанавливается	✅
Команды для тестирования
bash

# Выключить backend-1
virsh destroy backend-1
curl http://192.168.122.100/  # должен ответить

# Выключить nginx-1
virsh destroy nginx-1
curl http://192.168.122.100/  # должен ответить через nginx-2

# Восстановить
virsh start nginx-1
virsh start backend-1

