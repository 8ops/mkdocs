# LVM

在 Linux 中创建并使用新磁盘（物理磁盘、分区、LVM 逻辑卷或文件）通常涉及以下步骤：

------

## **1. 添加新物理磁盘**

### **① 检查新磁盘是否被系统识别**

bash

复制

```
lsblk       # 查看所有块设备（磁盘/分区）
fdisk -l    # 详细列出磁盘信息
```

如果新磁盘（如 `/dev/sdb`）未显示，可能需要重新扫描 SCSI 总线：

bash

复制

```
echo 1 > /sys/class/scsi_device/0\:0\:0\:0/device/rescan
```

### **② 分区（可选）**

使用 `fdisk` 或 `gdisk`（GPT 分区）：

bash

复制

```
fdisk /dev/sdb
```

- 按 `n` 创建新分区。
- 按 `t` 更改分区类型（如 `8e` 用于 LVM）。
- 按 `w` 保存并退出。

### **③ 格式化分区**

bash

复制

```
mkfs.ext4 /dev/sdb1   # 格式化为 ext4
mkfs.xfs /dev/sdb1    # 或 XFS
```

### **④ 挂载使用**

bash

复制

```
mkdir /mnt/newdisk
mount /dev/sdb1 /mnt/newdisk
```

永久挂载需修改 `/etc/fstab`：

bash

复制

```
echo "/dev/sdb1 /mnt/newdisk ext4 defaults 0 0" >> /etc/fstab
```

------

## **2. 使用 LVM 管理磁盘**

### **① 创建物理卷（PV）**

bash

复制

```
pvcreate /dev/sdb1    # 将分区初始化为 PV
pvs                   # 查看 PV
```

### **② 创建卷组（VG）**

bash

复制

```
vgcreate vg_data /dev/sdb1   # 创建名为 vg_data 的 VG
vgs                          # 查看 VG
```

### **③ 创建逻辑卷（LV）**

bash

复制

```
lvcreate -L 20G -n lv_data vg_data   # 创建 20GB 的 LV
lvs                                  # 查看 LV
```

### **④ 格式化并挂载 LV**

bash

复制

```
mkfs.ext4 /dev/vg_data/lv_data
mkdir /data
mount /dev/vg_data/lv_data /data
```

------

## **3. 创建虚拟磁盘文件（测试用）**

### **① 创建空文件作为虚拟磁盘**

bash

复制

```
dd if=/dev/zero of=/virtual_disk.img bs=1G count=10  # 创建 10GB 文件
```

### **② 格式化为 ext4 并挂载**

bash

复制

```
mkfs.ext4 /virtual_disk.img
mkdir /mnt/virtual
mount -o loop /virtual_disk.img /mnt/virtual
```

------

## **4. 扩展现有磁盘（LVM 动态扩容）**

### **① 扩展逻辑卷（LV）**

bash

复制

```
lvextend -L +5G /dev/vg_data/lv_data   # 增加 5GB
resize2fs /dev/vg_data/lv_data         # 调整文件系统（ext4）
xfs_growfs /dev/vg_data/lv_data        # 如果是 XFS
```

------

## **关键命令总结**

| 用途        | 命令示例                               |
| :---------- | :------------------------------------- |
| 查看磁盘    | `lsblk`、`fdisk -l`                    |
| 分区        | `fdisk /dev/sdb`                       |
| 格式化      | `mkfs.ext4 /dev/sdb1`                  |
| 挂载        | `mount /dev/sdb1 /mnt/newdisk`         |
| LVM 创建 PV | `pvcreate /dev/sdb1`                   |
| LVM 创建 VG | `vgcreate vg_data /dev/sdb1`           |
| LVM 创建 LV | `lvcreate -L 20G -n lv_data vg_data`   |
| 扩展 LV     | `lvextend -L +5G /dev/vg_data/lv_data` |