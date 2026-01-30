# Product Data

Product data is generated dynamically by `scripts/05-import-products.sh`.

## Product Catalog

The script creates realistic outdoor gear products including:
- Hiking boots and trail shoes
- Backpacks and packs
- Tents and shelters
- Sleeping bags
- Camping equipment
- Apparel and clothing
- Accessories

## Product Features

Each product includes:
- Realistic names and descriptions
- Price ranges appropriate for outdoor gear
- Product categories
- Stock quantities
- Product variations (sizes, colors) for some items

## Customization

Edit `scripts/05-import-products.sh` to:
- Add new products to the PRODUCTS array
- Modify product categories
- Change price ranges
- Add custom attributes
- Create variable products

## Image Handling

Product images are currently placeholders. Future enhancements may include:
- Downloading from Unsplash/Pexels
- Using local image library
- Generating placeholder images
