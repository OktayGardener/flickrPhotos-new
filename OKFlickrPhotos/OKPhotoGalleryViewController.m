//
//  ViewController.m
//  flickrPhotos
//
//  Created by Oktay Bahceci on 02/07/2015.
//  Copyright (c) 2015 Oktay Bahceci. All rights reserved.
//

#import "OKPhotoGalleryViewController.h"
#import "OKThumbnailCollectionViewCell.h"
#import "OKFullPhotoViewController.h"
#import "AFNetworking.h"

static NSString *const kFlickrAPIKey = @"6b2ee9fdfff13d9509b7c923dff01b91";

@interface OKPhotoGalleryViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) NSMutableArray *photos;

@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *activityView;
@property (nonatomic, weak) IBOutlet UICollectionView *flickrCollectionView;

@property (nonatomic, strong) NSMutableDictionary *thumbnailURLs;
@property (nonatomic, strong) NSMutableDictionary *imageURLs;

@end

@implementation OKPhotoGalleryViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
	[[self navigationController] setNavigationBarHidden:YES animated:YES];
	
	[self.flickrCollectionView setContentInset:UIEdgeInsetsMake(44, 0, 0, 0)];
	UISearchBar *searchBar = [[UISearchBar alloc]initWithFrame:CGRectMake(0, -44, self.view.frame.size.width, 44.0)];
	[self.flickrCollectionView addSubview:searchBar];
	searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	searchBar.delegate = self;
	
	[self.flickrCollectionView registerNib:[UINib nibWithNibName:NSStringFromClass([OKThumbnailCollectionViewCell class]) bundle:nil] forCellWithReuseIdentifier:@"CustomCell"];
	
	self.thumbnailURLs = [NSMutableDictionary dictionary];
	self.imageURLs = [NSMutableDictionary dictionary];
	
	[super viewDidLoad];
	[self.navigationController setNavigationBarHidden:YES];
	
	[self searchFlickrPhotos:@"Rihanna"];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
	return self.photos.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"CustomCell";
	OKThumbnailCollectionViewCell *cell = (OKThumbnailCollectionViewCell *)[collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
	
	NSURL *url = self.thumbnailURLs[@(indexPath.row)];
	if(url) {
		[self downloadImageAtURL:url completion:^(UIImage *image) {
			[cell.activityIndicator stopAnimating];
			[cell.cellSmallPhoto setImage:image];
		}];
	} else {
		[cell.activityIndicator startAnimating];
	}
	return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	OKFullPhotoViewController *fpvc = [[OKFullPhotoViewController alloc] initWithImageURL:self.imageURLs[@(indexPath.row)]];
	[self.navigationController pushViewController:fpvc animated:YES];
}

#pragma mark - Actions

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
	NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
	
	for (int i = 0; i < self.photos.count; i++) {
		[indexPaths addObject:[NSIndexPath indexPathForItem:i inSection:0]];
	}
	
	self.photos = [NSMutableArray array];
	self.thumbnailURLs = [NSMutableDictionary dictionary];
	self.imageURLs = [NSMutableDictionary dictionary];
	
	[self.flickrCollectionView deleteItemsAtIndexPaths:indexPaths];
	
	[searchBar endEditing:YES];
	[searchBar resignFirstResponder];
	
	[self searchFlickrPhotos:searchBar.text];
}

#pragma mark - New search

- (void)searchFlickrPhotos:(NSString *)text
{
	NSUInteger numberOfItems = 80;
	NSString *urlString = [NSString stringWithFormat:@"https://api.flickr.com/services/rest/?method=flickr.photos.search&api_key=%@&tags=%@&per_page=%ld&format=json&nojsoncallback=1", kFlickrAPIKey, text, (long)numberOfItems];
	
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:urlString]];
	
	AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
	operation.responseSerializer = [AFJSONResponseSerializer serializer];
	[operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
		
		self.photos = [[responseObject objectForKey:@"photos"] objectForKey:@"photo"];
		NSMutableArray *indexForPhotos = [[NSMutableArray alloc] init];
		for (int i = 0; i < [self.photos count]; i++) {
			NSIndexPath *anIndex = [NSIndexPath indexPathForItem:i inSection:0];
			[indexForPhotos addObject:anIndex];
		}
		[self.flickrCollectionView insertItemsAtIndexPaths:indexForPhotos];
		[self.photos enumerateObjectsUsingBlock:^(NSDictionary *photo, NSUInteger idx, BOOL *stop) {
			NSString *size = @"s";
			NSString *urlString = [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_%@.jpg", [photo objectForKey:@"farm"], [photo objectForKey:@"server"], [photo objectForKey:@"id"], [photo objectForKey:@"secret"], size];
			
			[self.thumbnailURLs setObject:[NSURL URLWithString:urlString] forKey:@(idx)];
			
			size = @"h";
			urlString = [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_%@.jpg", [photo objectForKey:@"farm"], [photo objectForKey:@"server"], [photo objectForKey:@"id"], [photo objectForKey:@"secret"], size];
			[self.imageURLs setObject:[NSURL URLWithString:urlString] forKey:@(idx)];
			
			[self.flickrCollectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:idx inSection:0]]];
		}];
		
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error retrieving image" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
		[alertView show];
		NSLog(@"%@", error);
	}];
	
	[operation start];
	
	/*	[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
		NSError *err;
		id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&err];
		
		if(err) {
	 return;
		}
		
		self.photos = [[json objectForKey:@"photos"] objectForKey:@"photo"];
		
		NSMutableArray *indexForPhotos = [[NSMutableArray alloc] init];
		for (int i = 0; i < [self.photos count]; i++) {
	 NSIndexPath *anIndex = [NSIndexPath indexPathForItem:i inSection:0];
	 [indexForPhotos addObject:anIndex];
		}
		[self.photos enumerateObjectsUsingBlock:^(NSDictionary *photo, NSUInteger idx, BOOL *stop) {
	 NSString *size = @"s";
	 NSString *urlString = [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_%@.jpg", [photo objectForKey:@"farm"], [photo objectForKey:@"server"], [photo objectForKey:@"id"], [photo objectForKey:@"secret"], size];
	 
	 [self.thumbnailURLs setObject:[NSURL URLWithString:urlString] forKey:@(idx)];
	 
	 size = @"h";
	 urlString = [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_%@.jpg", [photo objectForKey:@"farm"], [photo objectForKey:@"server"], [photo objectForKey:@"id"], [photo objectForKey:@"secret"], size];
	 [self.imageURLs setObject:[NSURL URLWithString:urlString] forKey:@(idx)];
	 
	 [self.flickrCollectionView reloadItemsAtIndexPaths:@[[NSIndexPath indexPathForItem:idx inSection:0]]];
		}];
	 }]; */
	
}

- (void)downloadImageAtURL:(NSURL *)url completion:(void(^)(UIImage *image))completion
{
	NSURLRequest *request = [NSURLRequest requestWithURL:url];
	AFHTTPRequestOperation *requestOperation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
	[requestOperation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
		UIImage *image = [UIImage imageWithData:responseObject];
		completion(image);
	} failure:^(AFHTTPRequestOperation *operation, NSError *error) {
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error retrieving image" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
		[alertView show];
		NSLog(@"%@", error);
	}];
	
	[requestOperation start];
	
	/* NSURL code:
	 [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:url] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error){
		UIImage *image = [UIImage imageWithData:data];
		if(completion) {
	 completion(image);
		}
	 }]; */
}

@end
