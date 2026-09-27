# 引导与内核。
{ pkgs, ... }:

{
  # 使用 Limine 引导（UEFI，/boot 即 EFI 系统分区）。
  boot.loader.limine.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 引导菜单最多保留最近三代，与系统 profile 的清理保持一致。
  boot.loader.limine.maxGenerations = 3;

  boot.kernelPackages = pkgs.linuxPackages_latest;
    # 2. 设置启动菜单超时时间为 5 秒
  boot.loader.timeout = 15;

  # 3. Limine 的详细配置
  boot.loader.limine = {
    # 启用 EFI 支持（现代电脑通常需要）
    efiSupport = true;

    # 允许在启动时编辑启动项（可选，但为了安全建议设为 false）
    enableEditor = false;

    # 记住上次选择的启动项（UEFI only）
    extraConfig = ''
      remember_last_entry: yes
    '';

    # 4. 添加 Windows 启动项
    # uuid() 使用 Windows ESP（nvme0n1p1）的 GPT 分区 GUID
    extraEntries = ''
      /Win 11
          protocol: efi
          path: uuid(f4edaf51-83b0-4918-8a18-70a6ce12f69f):/EFI/Microsoft/Boot/bootmgfw.efi
    '';
  };
}

