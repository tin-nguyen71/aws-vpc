################################################################################
# Transit Gateway Attachment And Routes
################################################################################
locals {
  # route_table           = try(concat(aws_route_table.private[*].id, aws_route_table.public[*].id), [])
  database_route_tables      = try(aws_route_table.database[*].id, null)
  private_route_tables       = try(aws_route_table.private[*].id, null)
  public_route_tables        = try(aws_route_table.public[*].id, null)
  database_route_config_list = local.database_route_tables != null ? setproduct(local.database_route_tables, var.tgw_destination_cidr_blocks_of_database_subnets) : []
  private_route_config_list  = local.private_route_tables != null ? setproduct(local.private_route_tables, var.tgw_destination_cidr_blocks_of_private_subnets) : []
  public_route_config_list   = local.public_route_tables != null ? setproduct(local.public_route_tables, var.tgw_destination_cidr_blocks_of_public_subnets) : []
  # max_route_transit     = local.nat_gateway_count * length(var.destination_cidr_blocks)
  #route_config_map      = local.route_config_provided ? { for i in local.route_config_list : format("%v:%v", i[0], i[1]) => i } : {}
  create_vpc_attachment = local.create_vpc && var.create_vpc_attachment && var.transit_gateway_id != "" && var.transit_gateway_id != null
}

resource "aws_ec2_transit_gateway_vpc_attachment" "transit_gateway_attachment" {
  count                                           = local.create_vpc_attachment ? 1 : 0
  subnet_ids                                      = aws_subnet.private[*].id
  transit_gateway_id                              = var.transit_gateway_id
  vpc_id                                          = aws_vpc.vpc[0].id
  dns_support                                     = var.vpc_attachment_dns_support
  ipv6_support                                    = var.vpc_attachment_ipv6_support
  appliance_mode_support                          = var.vpc_attachment_appliance_mode_support
  transit_gateway_default_route_table_association = var.default_route_table_association
  transit_gateway_default_route_table_propagation = var.default_route_table_propagation
  tags = merge(
    var.tags,
    {
      Name = format("%s-tgw-attachment", local.vpc_name)
    }
  )
}

resource "aws_ec2_transit_gateway_route_table_association" "route_table_association" {
  for_each                       = local.create_vpc_attachment && length(var.transit_gateway_route_table_ids) > 0 && !var.default_route_table_association ? var.transit_gateway_route_table_ids : {}
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.transit_gateway_attachment[0].id
  transit_gateway_route_table_id = each.value

  provider = aws.network
}

resource "aws_ec2_transit_gateway_route_table_propagation" "route_table_propagation" {
  for_each                       = local.create_vpc_attachment && length(var.transit_gateway_route_table_ids) > 0 && !var.default_route_table_propagation ? var.transit_gateway_route_table_ids : {}
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.transit_gateway_attachment[0].id
  transit_gateway_route_table_id = each.value

  provider = aws.network
}

resource "aws_route" "private_transit_gateway" {
  count                  = local.create_vpc_attachment ? length(var.private_subnets) : 0
  transit_gateway_id     = var.transit_gateway_id
  route_table_id         = local.private_route_config_list[count.index][0]
  destination_cidr_block = local.private_route_config_list[count.index][1]

  timeouts {
    create = "5m"
  }
  depends_on = [
    aws_route_table.private,
    aws_ec2_transit_gateway_vpc_attachment.transit_gateway_attachment
  ]
}

resource "aws_route" "public_transit_gateway" {
  count                  = local.create_vpc_attachment && var.enable_transit_route_for_public_subnet ? length(var.public_subnets) : 0
  transit_gateway_id     = var.transit_gateway_id
  route_table_id         = local.public_route_config_list[count.index][0]
  destination_cidr_block = local.public_route_config_list[count.index][1]

  timeouts {
    create = "5m"
  }
  depends_on = [
    aws_route_table.public,
    aws_ec2_transit_gateway_vpc_attachment.transit_gateway_attachment
  ]
}

resource "aws_route" "database_transit_gateway" {
  count                  = local.create_vpc_attachment && var.enable_transit_route_for_database_subnet ? length(var.database_subnets) : 0
  transit_gateway_id     = var.transit_gateway_id
  route_table_id         = local.database_route_config_list[count.index][0]
  destination_cidr_block = local.database_route_config_list[count.index][1]

  timeouts {
    create = "5m"
  }
  depends_on = [
    aws_route_table.database,
    aws_ec2_transit_gateway_vpc_attachment.transit_gateway_attachment
  ]
}
