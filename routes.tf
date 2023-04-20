################################################################################
# Database routes
################################################################################
resource "aws_route_table" "database" {
  count = local.create_vpc && var.create_database_subnet_route_table && length(var.database_subnets) > 0 ? var.single_nat_gateway ? 1 : length(var.database_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = var.single_nat_gateway ? "${local.vpc_name}-${var.database_subnet_suffix}" : format(
        "${local.vpc_name}-${var.database_subnet_suffix}-%s",
        element(local.azs, count.index),
      )
    },
    var.tags,
    var.database_route_table_tags,
  )
}

resource "aws_route" "database_nat_gateway" {
  count                  = local.create_vpc && var.create_database_subnet_route_table && length(var.database_subnets) > 0 && var.create_database_nat_gateway_route && var.enable_nat_gateway ? var.single_nat_gateway ? 1 : length(var.database_subnets) : 0
  route_table_id         = element(aws_route_table.database[*].id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, count.index)

  timeouts {
    create = "5m"
  }
}

################################################################################
# Intra routes
################################################################################
resource "aws_route_table" "intra" {
  count = local.create_vpc && length(var.intra_subnets) > 0 ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(
    { "Name" = "${local.vpc_name}-${var.intra_subnet_suffix}" },
    var.tags,
    var.intra_route_table_tags,
  )
}

################################################################################
# NAT Gateway routes
################################################################################
resource "aws_route" "private_nat_gateway" {
  count = local.create_vpc && var.enable_nat_gateway ? length(var.private_subnets) : 0

  route_table_id         = element(aws_route_table.private[*].id, count.index)
  destination_cidr_block = var.nat_gateway_destination_cidr_block
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, count.index)

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "private_ipv6_egress" {
  count = local.create_vpc && var.create_egress_only_igw && var.enable_ipv6 ? length(var.private_subnets) : 0

  route_table_id              = element(aws_route_table.private[*].id, count.index)
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = element(aws_egress_only_internet_gateway.this[*].id, 0)
}

################################################################################
# Private routes
# There are as many routing tables as the number of NAT gateways
################################################################################
resource "aws_route_table" "private" {
  count = local.create_vpc && local.max_subnet_length > 0 ? local.max_subnet_length : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = format(
        "${local.vpc_name}-${var.private_subnet_suffix}-%s",
        element(local.azs, count.index),
      )
    },
    var.tags,
    var.private_route_table_tags,
  )
}

################################################################################
# Publiс routes
################################################################################
resource "aws_route_table" "public" {
  count = local.create_vpc && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(
    {
      "Name" = format(
        "${local.vpc_name}-${var.public_subnet_suffix}-%s",
        element(local.azs, count.index),
      )
    },
    var.tags,
    var.public_route_table_tags,
  )
}

resource "aws_route" "public_internet_gateway" {
  count = local.create_vpc && var.create_igw && length(var.public_subnets) > 0 ? length(var.public_subnets) : 0

  route_table_id = element(aws_route_table.public[*].id, count.index)

  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "public_internet_gateway_ipv6" {
  count = local.create_vpc && var.create_igw && var.enable_ipv6 && length(var.public_subnets) > 0 ? 1 : 0

  route_table_id              = aws_route_table.public[0].id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.this[0].id
}
