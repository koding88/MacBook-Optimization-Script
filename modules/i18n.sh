#!/bin/bash

# ==============================================================================
# Module: i18n.sh
# Purpose: Internationalization (English & Spanish language support)
# ==============================================================================

CURRENT_LANG="ES" # Default language (ES: Spanish, EN: English)

function set_language() {
    local lang_input="${1^^}"
    if [ "$lang_input" = "EN" ] || [ "$lang_input" = "ENGLISH" ]; then
        CURRENT_LANG="EN"
    else
        CURRENT_LANG="ES"
    fi
}

function t() {
    local key="$1"
    
    if [ "$CURRENT_LANG" = "ES" ]; then
        case "$key" in
            # Header & Summaries
            "TITLE") echo "MacBook Optimization Script v2.0" ;;
            "SYS_INFO") echo "Información del Sistema" ;;
            "TOTAL_RUN") echo "Ejecutados" ;;
            "ENABLED") echo "Habilitados" ;;
            "FAILED") echo "Fallidos" ;;
            "NOT_RUN") echo "NO EJECUTADO" ;;
            "PRESS_ENTER") echo "Presione Enter para continuar..." ;;
            "INVALID_CHOICE") echo "Opción no válida. Ingrese una opción válida." ;;
            "QUIT_MSG") echo "Saliendo del script de optimización. ¡Hasta luego!" ;;
            
            # Sections
            "SEC_SYS") echo "Optimizaciones de Sistema" ;;
            "SEC_NET") echo "Optimizaciones de Red" ;;
            "SEC_STO") echo "Optimizaciones de Almacenamiento" ;;
            "SEC_PERF") echo "Ajustes de Rendimiento" ;;
            "SEC_MAINT") echo "Mantenimiento del Sistema" ;;
            "SEC_MONITOR") echo "Monitoreo y Diagnóstico" ;;
            "SEC_LANG") echo "Idioma / Language" ;;
            
            # Options
            "OPT_SYS_PERF") echo "Optimizar Rendimiento del Kernel" ;;
            "OPT_MEM") echo "Optimizar Gestión de Memoria RAM" ;;
            "OPT_SSD") echo "Optimizar Ajustes de SSD" ;;
            "OPT_SEC") echo "Optimizar Ajustes de Seguridad" ;;
            "OPT_PWR") echo "Optimizar Gestión de Energía" ;;
            "OPT_NET") echo "Optimizar Pila de Red TCP/IP" ;;
            "OPT_DNS") echo "Vaciar Caché DNS" ;;
            "OPT_FIREWALL") echo "Habilitar Firewall de Red" ;;
            "OPT_CACHE") echo "Limpiar Cachés de Sistema y Usuario" ;;
            "OPT_LANG_CLEAN") echo "Verificar/Eliminar Idiomas No Usados" ;;
            "OPT_FONT") echo "Limpiar Cachés de Fuentes" ;;
            "OPT_DS_STORE") echo "Eliminar Archivos .DS_Store" ;;
            "OPT_SPOTLIGHT") echo "Gestionar Indexación de Spotlight" ;;
            "OPT_DASHBOARD") echo "Desactivar Dashboard (OS Legacy)" ;;
            "OPT_ANIM") echo "Desactivar Animaciones de Ventana" ;;
            "OPT_DOCK") echo "Optimizar Velocidad del Dock" ;;
            "OPT_DISK_PERM") echo "Verificar Integridad de Volumen APFS" ;;
            "OPT_MAINT_SCRIPTS") echo "Ejecutar Scripts Diarios/Semanales/Mensuales" ;;
            "OPT_LOG_CLEAN") echo "Vaciar Archivos de Log" ;;
            "OPT_SMC") echo "Instrucciones para Reset de SMC" ;;
            "OPT_VIEW_ALL") echo "Ver Estado de Todas las Optimizaciones" ;;
            "OPT_RESET_TRACKER") echo "Restablecer Registro de Estado" ;;
            "OPT_SYS_CHECK") echo "Diagnóstico y Estado de Hardware" ;;
            "OPT_PWR_SAVING") echo "Alternar Modo de Bajo Consumo" ;;
            "OPT_AUTOBOOT") echo "Alternar AutoBoot (Solo Intel)" ;;
            "OPT_MDM") echo "Verificar Estado de MDM" ;;
            "OPT_ROLLBACK") echo "Revertir Cambios a Estado Anterior / Fábrica" ;;
            "OPT_TOGGLE_LANG") echo "Cambiar Idioma (Español / English)" ;;
            "OPT_VIEW_LOGS") echo "Ver Registros de Log (~/.macbook_optimizer.log)" ;;
            "OPT_QUIT") echo "Salir" ;;
            *) echo "$key" ;;
        esac
    else
        case "$key" in
            # Header & Summaries
            "TITLE") echo "MacBook Optimization Script v2.0" ;;
            "SYS_INFO") echo "System Info" ;;
            "TOTAL_RUN") echo "Total Run" ;;
            "ENABLED") echo "Enabled" ;;
            "FAILED") echo "Failed" ;;
            "NOT_RUN") echo "NOT RUN" ;;
            "PRESS_ENTER") echo "Press Enter to continue..." ;;
            "INVALID_CHOICE") echo "Invalid choice. Please enter a valid option." ;;
            "QUIT_MSG") echo "Quitting MacBook Optimization Script. Goodbye!" ;;
            
            # Sections
            "SEC_SYS") echo "System Optimizations" ;;
            "SEC_NET") echo "Network Optimizations" ;;
            "SEC_STO") echo "Storage Optimizations" ;;
            "SEC_PERF") echo "Performance Tweaks" ;;
            "SEC_MAINT") echo "Maintenance" ;;
            "SEC_MONITOR") echo "Monitoring & Diagnostics" ;;
            "SEC_LANG") echo "Language Settings" ;;
            
            # Options
            "OPT_SYS_PERF") echo "Optimize System Kernel Performance" ;;
            "OPT_MEM") echo "Optimize Memory Management" ;;
            "OPT_SSD") echo "Optimize SSD Settings" ;;
            "OPT_SEC") echo "Optimize Security Settings" ;;
            "OPT_PWR") echo "Optimize Power Settings" ;;
            "OPT_NET") echo "Optimize Network Stack" ;;
            "OPT_DNS") echo "Flush DNS Cache" ;;
            "OPT_FIREWALL") echo "Enable Network Firewall" ;;
            "OPT_CACHE") echo "Clear System & User Caches" ;;
            "OPT_LANG_CLEAN") echo "Check/Remove Unused Languages" ;;
            "OPT_FONT") echo "Clear Font Caches" ;;
            "OPT_DS_STORE") echo "Remove .DS_Store Files" ;;
            "OPT_SPOTLIGHT") echo "Manage Spotlight Indexing" ;;
            "OPT_DASHBOARD") echo "Disable Dashboard (Legacy OS)" ;;
            "OPT_ANIM") echo "Disable Window Animations" ;;
            "OPT_DOCK") echo "Optimize Dock Speed" ;;
            "OPT_DISK_PERM") echo "Verify APFS Volume Integrity" ;;
            "OPT_MAINT_SCRIPTS") echo "Run Daily/Weekly/Monthly Scripts" ;;
            "OPT_LOG_CLEAN") echo "Clear System Logs" ;;
            "OPT_SMC") echo "Reset SMC Instructions" ;;
            "OPT_VIEW_ALL") echo "View All Optimization States" ;;
            "OPT_RESET_TRACKER") echo "Reset Optimization Tracker State" ;;
            "OPT_SYS_CHECK") echo "Hardware Diagnostics & Status" ;;
            "OPT_PWR_SAVING") echo "Toggle Power Saving Mode" ;;
            "OPT_AUTOBOOT") echo "Toggle AutoBoot (Intel Only)" ;;
            "OPT_MDM") echo "Check MDM Enrollment Status" ;;
            "OPT_ROLLBACK") echo "Rollback Tweaks to Previous / Factory State" ;;
            "OPT_TOGGLE_LANG") echo "Switch Language (Español / English)" ;;
            "OPT_VIEW_LOGS") echo "View Log Records (~/.macbook_optimizer.log)" ;;
            "OPT_QUIT") echo "Quit" ;;
            *) echo "$key" ;;
        esac
    fi
}
