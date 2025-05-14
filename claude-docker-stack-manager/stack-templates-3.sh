# Main function (continued)
main() {
    if [ $# -eq 0 ]; then
        show_templates
        echo
        echo "Usage: $0 <template-number> <stack-name> [options]"
        echo "Example: $0 1 mywebserver 8080 8443"
        exit 0
    fi

    template_number="$1"
    stack_name="$2"

    if [ -z "$stack_name" ]; then
        echo "Error: Stack name is required"
        echo "Usage: $0 <template-number> <stack-name> [options]"
        exit 1
    fi

    case $template_number in
        1)
            shift 2
            create_nginx_template "$stack_name" "$@"
            ;;
        2)
            shift 2
            create_mysql_template "$stack_name" "$@"
            ;;
        3)
            shift 2
            create_postgres_template "$stack_name" "$@"
            ;;
        4)
            shift 2
            create_wordpress_template "$stack_name" "$@"
            ;;
        5)
            shift 2
            create_lamp_template "$stack_name" "$@"
            ;;
        6)
            shift 2
            create_monitoring_template "$stack_name" "$@"
            ;;
        7)
            shift 2
            create_traefik_template "$stack_name" "$@"
            ;;
        8)
            shift 2
            create_plex_template "$stack_name" "$@"
            ;;
        9)
            shift 2
            create_nodejs_template "$stack_name" "$@"
            ;;
        10)
            shift 2
            create_flask_template "$stack_name" "$@"
            ;;
        *)
            echo "Invalid template number: $template_number"
            show_templates
            exit 1
            ;;
    esac

    echo -e "${GREEN}Template generated successfully!${NC}"
    echo "To deploy your stack:"
    echo "  cd $STACKS_DIR/$stack_name"
    echo "  docker compose up -d"
}

# Execute main function with all arguments
main "$@"